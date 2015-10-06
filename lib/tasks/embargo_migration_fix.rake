require './lib/tasks/migration/migration_logger'
require 'csv'

namespace :migration do
  desc "fix visibility of previously migrated embargoed items"
  task :fix_embargo, [:embargo_file] => :environment do |t, args|
    begin
      MigrationLogger.info "***************START: Fix Embargo ***************"
      embargo_file = args.embargo_file
      if File.exists?(embargo_file) && File.file?(embargo_file)
        fix_embargo(embargo_file)
      else
        MigrationLogger.fatal "Invalid file #{embargo_file}"
      end
      MigrationLogger.info "****************FINISH: Embargo Migration **************"
    rescue
      raise
    end
  end
end

def fix_embargo(embargo_file)
  embargos = CSV.parse(File.read(embargo_file))
  embargos.each do |row|
    uid = row[0]
    begin
      embargo_date = Time.parse(row[1]).strftime('%Y-%m-%d')
    rescue
      MigrationLogger.info "Date was not parsed and raised error"
      next
    end

    solr_rsp =  ActiveFedora::SolrService.instance.conn.get 'select', :params => {:q => Solrizer.solr_name('fedora3uuid')+':'+uid}
    gf = GenericFile.find(solr_rsp['response']['docs'].first['id'])

    unless gf.fedora3uuid == uid
      MigrationLogger.info "Mismatch uuid: #{uid} vs #{gf.fedora3uuid}"
      next
    end

    gf.apply_embargo(embargo_date,Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE,Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC)

    # save the file
    MigrationLogger.info "Save the file"
    save_tries = 0
    begin
      return false unless gf.save
    rescue RSolr::Error::Http => error
      ActiveFedora::Base.logger.warn "Sufia::GenericFile::Actor::save_and_record_committer Caught RSOLR error #{error.inspect}"
      MigrationLogger.warn "ERROR #{error.inspect} when saving the file #{uuid}"
      save_tries+=1
      # fail for good if the tries is greater than 3
      raise error if save_tries >=3
        sleep 0.01
        retry
    end
  end
end
