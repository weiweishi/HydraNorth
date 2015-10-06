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
    embargo_date = row[1] 
    gf = GenericFile.where(Solrizer.solr_name("fedora3uuid", :stored_searchable, type: :string) => uid)
    gf.visibilty = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_EMBARGO
    gf.visibility_during_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    gf.visibility_after_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    gf.embargo_release_date = embargo_date

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
