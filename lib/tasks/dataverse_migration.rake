require 'fileutils'
require './lib/tasks/migration/migration_logger'

namespace :migration do
	
  desc "batch migrate object metadata from Dataverse' OAI-DC"
  task :dataverse_objects, [:dir] => :environment do |t, args|
    begin
      MigrationLogger.info "**************START: Migrate metadata for Dataverse objects *******************"
      metadata_dir = args.dir 
      # Usage: Rake migration:dataverse_objects[<file directory here, path included>] 
      if File.exist?(metadata_dir) && File.directory?(metadata_dir)
        migrate_dataverse_objects(metadata_dir) 
      else
	MigrationLogger.fatal "Invalid directory #{metadata_dir}"
      end
      MigrationLogger.info "**************FINISH: Migrate metadata for Dataverse objects ******************"
    rescue
      raise
    end
  end

  desc "Fix Dataverse items' rights and description fields."
  task update_dataverse_fields: :environment do
    solr_rsp = ActiveFedora::SolrService.instance.conn.get 'select', :params => {:fq => 'hasCollection_tesim:"Dataverse Datasets"', :fl =>'id' }
    numFound = solr_rsp['response']['numFound']
    solr_rsp = ActiveFedora::SolrService.instance.conn.get 'select', :params => {:fq => 'hasCollection_tesim:"Dataverse Datasets"', :fl =>'id', :rows => numFound }
    idList = solr_rsp['response']['docs']
    idList.each do |o|
      id = o['id']
      MigrationLogger.error "Object: " + id
      file = GenericFile.find(id)
      file.rights = nil
      file.hasCollectionId =['wm117p010']
      file.description ||= [""]
      new_statement = "This item is a resource in the University of Alberta Libraries' Dataverse Network. Access this item in Dataverse by clicking on the DOI link. | "
      file.description = ["#{new_statement}#{file.description[0]}"]
      file.save
      file = GenericFile.find(id)
    end
  end


  def migrate_dataverse_objects(metadata_dir)
    MigrationLogger.info " +++++++ START: object ingest #{metadata_dir} +++++++ "
    # create a ingest batch
    @ingest_batch_id = ActiveFedora::Noid::Service.new.mint
    @ingest_batch = Batch.find_or_create(@ingest_batch_id)
    MigrationLogger.info "Ingest Batch ID #{@ingest_batch_id}"
    #for each metadata file in the migration directory
    Dir.glob(metadata_dir+"/*/export_oai_dcterms.xml") do |file|
    begin
      object_id = File.dirname(file)[/(\d\d\d\d\d)/, 1]
      MigrationLogger.info "Processing the object #{object_id}"
      #reading the metadata file
      metadata_file = Nokogiri::XML(File.open(file))
      metadata = metadata_file.xpath("//oai_dc:dcterms",NS)
      #get the doi of the object
      identifier = metadata.xpath("dcterms:identifier", NS).text
      
      # check duplication in the system
      next if duplicated?(identifier)
  
      # set the owner id to a generic dataverse account (currently with dit.application.test@ualberta.ca email address)
      owner_id = "dit.application.test@ualberta.ca"
 
      title = metadata.xpath("dcterms:title", NS).text
      identifier = metadata.xpath("dcterms:identifier", NS).text
      creators = metadata.xpath("dcterms:creator/text()", NS).map(&:to_s) if metadata.xpath("dcterms:creator", NS)
      subjects = metadata.xpath("dcterms:subject/text()",NS).map(&:to_s)
      description = metadata.xpath("dcterms:description/text()",NS).map(&:to_s)
      publisher = metadata.xpath("dcterms:publisher/text()",NS).text if metadata.xpath("dcterms:publisher", NS)
      
      #description.gsub!(/"/, '\"').gsub!(/\n/,' ').gsub!(/\t/,' ') if description
   
      date = metadata.xpath("dcterms:created",NS).text
      year_created = date[/(\d\d\d\d)/,0] unless date.nil? || date.blank? 
      type = "Dataset"
      spatials = metadata.xpath("dcterms:spatial/text()",NS).map(&:to_s)
      temporals = metadata.xpath("dcterms:temporal/text()", NS).map(&:to_s)
      rights = metadata.xpath("dcterms:rights/text()", NS).map(&:to_s).join(" ")
	  
      # create the depositor
      depositor = User.find_by_email(owner_id)

      if !depositor
        depositor = User.new({
               :username => "dataverse",
               :email => owner_id,  
               :password => "reset_password",
               :password_confirmation => "reset_password",
               :group_list => "admin",
               })
      end

     # This is something we can discuss with stakeholders if we will create users for all creators
     #permissions_attributes = []
     #coowners = owner_ids - [depositor_id]
     #if coowners.count > 0
     #  coowners.each do |u|
     #    coowner = User.find_by_username(u)
     #    coowner = User.new({
     #          :username => u,
     #          :email => u +"@hydranorth.ca",
     #          :password => "reset_password",
     #          :password_confirmation => "reset_password",
     #          :group_list => "regular"
     #         }) if !coowner
     #    permissions_attributes << {type: 'user', name: coowner.user_key, access: 'edit'}
     #   end
     # end
      # set the time
      time_in_utc = DateTime.now

      # create the batch for the file upload
      @batch_id = ActiveFedora::Noid::Service.new.mint
      @batch = Batch.find_or_create(@batch_id)
      # create the generic file
      @generic_file = GenericFile.new
	  
      # create metadata for the new object in Hydranorth
      MigrationLogger.info "Create Metadata for new GenericFile: #{@generic_file.id}"
	  
      @generic_file.apply_depositor_metadata(depositor.user_key)
      # set date_uploaded/date_modified to current time, need to discuss with metadata team to see if the info can be obtained elsewhere in the system?
      @generic_file.date_uploaded = DateTime.now 
      @generic_file.date_modified = DateTime.now
	 
      if @batch_id
        @generic_file.batch_id = @batch_id
      else
        ActiveFedora::Base.logger.warn "unable to find batch to attach to"
      end

      # add other metadata to the new object
      @generic_file.title = [title]
      file_attributes = {"resource_type"=>[type], "description"=>description, "date_created"=>date, "year_created"=>year_created, "rights"=>rights, "subject"=>subjects, "spatial"=>spatials, "temporal"=>temporals, "identifier"=>[identifier], "ingestbatch" => @ingest_batch_id, "publisher"=>[publisher], "remote_resource" => "dataverse"}
      @generic_file.attributes = file_attributes
      # OPEN ACCESS for all items ingested for now
      @generic_file.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      MigrationLogger.info "Generic File attribute set id:#{@generic_file.id}"
      dataverse_dataset = Collection.find_with_conditions('title' => 'Dataverse Datasets')
      if !dataverse_dataset.present?
        c = Collection.new('title'=> 'Dataverse Datasets')
        c.apply_depositor_metadata("dit.application.test@ualberta.ca")
        c.save!
        id = c.id
      else
        id = dataverse_dataset.first['id']
      end
      community = Collection.find(id) 
      @generic_file.hasCollection = [community.title]
      

      # save the file
      MigrationLogger.info "Save the file"
      save_tries = 0
      begin
        return false unless @generic_file.save
      rescue RSolr::Error::Http => error
        ActiveFedora::Base.logger.warn "Sufia::GenericFile::Actor::save_and_record_committer Caught RSOLR error #{error.inspect}"
        MigrationLogger.warn "ERROR #{error.inspect} when saving the file"
                save_tries+=1
      # fail for good if the tries is greater than 3
      raise error if save_tries >=3
        sleep 0.01
        retry
      end
      #save creators seperately to keep the order of the authors
      @generic_file.creator = creators
      @generic_file.save
      MigrationLogger.info "Generic File saved id:#{@generic_file.id}"	  
      MigrationLogger.info "Generic File created id:#{@generic_file.id}"
      MigrationLogger.info "Add file to community dataverse"
      community.member_ids = community.member_ids.push(@generic_file.id)
      community.save 
      MigrationLogger.info "Finish migrating the file"

      rescue Exception => e
        puts "FAILED: Item #{object_id} migration!"
        puts e.message
        puts e.backtrace.inspect
        MigrationLogger.error "#{$!}, #{$@}"
        next
      end 
      begin 
      MigrationLogger.info "START: verify if migration is successful"
      # verify file is migrated
      migrated = GenericFile.find(@generic_file.id)
      # verify file is added to the collection
      incollection = !community.member_ids.include?(@generic_file.id)
      # remove the file from temp location
      if migrated && incollection
        MigrationLogger.info "file migrated successfully"
      end
      rescue
        puts "FAILED: Verification of migration #{uuid}!"
        MigrationLogger.error "#{$!}, #{$@}"
        next
      end
    end
  end

  private

  def save_file(file)
    save_tries = 0
      begin
        return false unless file.save
      rescue RSolr::Error::Http => error
        ActiveFedora::Base.logger.warn "Sufia::GenericFile::Actor::save_and_record_committer Caught RSOLR error #{error.inspect}"
        MigrationLogger.warn "ERROR #{error.inspect} when saving the file"
		save_tries+=1
      # fail for good if the tries is greater than 3
      raise error if save_tries >=3
        sleep 0.01
        retry
      end

    
  end

  def duplicated?(identifier)
    solr_rsp =  Blacklight.default_index.connection.get 'select', :params => {:q => 'identifier_tesim:'+identifier}
    numFound = solr_rsp['response']['numFound']
	return true if numFound > 0
  end

  def find_collection(title)
    id = Collection.find_with_conditions('title' => title).first['id']
    return Collection.find(id)
  end

	
end
