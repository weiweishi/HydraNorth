module Hydranorth
  module BatchEditsControllerBehavior
    extend ActiveSupport::Concern
    include Hydranorth::Breadcrumbs
    include Sufia::BatchEditsControllerBehavior

    def edit
      @generic_file = ::GenericFile.new
      @generic_file.depositor = current_user.user_key
      @terms = terms - [:title, :format, :resource_type]

      h = {}
      @names = []
      permissions = []

      # For each of the files in the batch, set the attributes to be the concatination of all the attributes
      batch.each do |doc_id|
        gf = ::GenericFile.load_instance_from_solr(doc_id)
        terms.each do |key|
          val = gf.send(key)
          if val.is_a? Array
            h[key] ||= []
            h[key] = (h[key] + val).uniq
          else
            h[key] = val
          end
        end
        @names << gf.to_s
        permissions = (permissions + gf.permissions).uniq
      end

      initialize_fields(h, @generic_file)

      @generic_file.permissions_attributes = [{ type: 'group', name: 'public', access: 'read' }]
    end

    def redirect_to_return_controller
      if params[:return_controller]
        redirect_to url_for(controller: params[:return_controller], only_path: true)
      else
        redirect_to sufia.dashboard_index_path
      end
    end

    protected

    def initialize_fields(attributes, file)
       terms.each do |key|
         file[key] = attributes[key]
       end
     end


    def terms
      Hydranorth::Forms::BatchEditForm.terms
    end

    def generic_file_params
      Hydranorth::Forms::BatchEditForm.model_attributes(params[:generic_file])
    end

  end
end
