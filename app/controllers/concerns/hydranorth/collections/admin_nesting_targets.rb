module Hydranorth::Collections::AdminNestingTargets
  def admin_target_collections
    logic = [:default_solr_parameters,
             :add_query_to_solr,
             :add_facet_fq_to_solr,
             :add_facetting_to_solr,
             :add_solr_fields_to_query,
             :add_paging_to_solr,
             :add_sorting_to_solr,
             :add_group_config_to_solr,
             :add_facet_paging_to_solr,
             :add_advanced_parse_q_to_solr,
             :show_only_collections]
    (response, document_list) = search_results({}, logic)
    #binding.pry
    document_list.sort! { |a,b| a.title <=> b.title }
  end
end
