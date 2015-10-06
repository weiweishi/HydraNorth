require './lib/tasks/migration/migration_logger'
require 'csv'

namespace :migration do
  desc "fix visibility of previously migrated ccid-protected items"
  task :fix_ccid, [:ccid_file] => :environment do |t, args|
    begin
      MigrationLogger.info "***************START: Fix CCID Protected Items ***************"
      ccid_file = args.ccid_file
      if File.exists?(ccid_file) && File.file?(ccid_file)
        fix_ccid(ccid_file)
      else
        MigrationLogger.fatal "Invalid file #{ccid_file}"
      end
      MigrationLogger.info "****************FINISH: CCID Protected Items Fix **************"
    rescue
      raise
    end
  end
end

def fix_embargo(ccid_file)
  ccids = CSV.parse(File.read(ccid_file))
  ccids.each do |row|
    uid = row[0]
    gf = GenericFile.where(Solrizer.solr_name("fedora3uuid", :stored_searchable, type: :string) => uid)
    gf.visibilty = Hydra::AccessControls::AccessControls::InstitutionalVisibility::UNIVERSITY_OF_ALBERTA
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
