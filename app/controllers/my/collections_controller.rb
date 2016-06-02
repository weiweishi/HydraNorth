class My::CollectionsController < MyController
  include Hydranorth::Collections::SelectsCollections
  include Hydranorth::Collections::AdminNestingTargets

  helper_method :valid_target_collections

  self.search_params_logic += [
    # NB this isn't accounting for admin properly
    :show_only_collections
  ]

  def index
    # admin users should see more than just collections where
    # their name is on the view/edit record
    self.search_params_logic += [
      :show_only_files_with_access
    ] unless @current_user.admin?
    @target_collections = admin_target_collections
    super
    @selected_tab = :collections
  end


  protected

  def search_action_url(*args)
    sufia.dashboard_collections_url(*args)
  end

end
