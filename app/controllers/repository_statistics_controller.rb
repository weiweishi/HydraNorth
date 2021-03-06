class RepositoryStatisticsController < ApplicationController

  def facet_stats
    # since the homepage will be seeing the most traffic, cache infrequently changing results
    # to cut down on the impact of the extra requests generated by the new dynamic stats
    response = Rails.cache.fetch(:repository_stats, expires_in: 5.minutes) do
      results = ActiveFedora::SolrService.instance.conn.get("select",
                                                            params: {q: 'active_fedora_model_ssi:"GenericFile"',
                                                                     rows: 0,
                                                                     wt: 'json',
                                                                     indent: true,
                                                                     facet: true,
                                                                     :'facet.field' => 'resource_type_sim'})

      # the total repository count needs to be a human-friendly string, eg) '12,345,678'
      # not the integer 12345678, for proper display
      count = ActiveSupport::NumberHelper.number_to_delimited(results[:response][:numFound])

      # resource_type_sim is an array of the form ['Thesis', 123, 'Report', 789,...] etc
      # stats becomes a Hash of the form {'Thesis' => 123, 'Report' => 789, ...} etc
      stats = Hash[*(results[:facet_counts][:facet_fields][:resource_type_sim])]

      facet_stats = chartify(stats)

      {facets: facet_stats, total_count: count}.to_json
    end

    respond_to do |format|
      format.json { render json: response }
      # visiting /stats in your browser will get you a 404 page
      format.any { raise ActiveRecord::RecordNotFound }
    end
  end

  private

  # convert the facet counts from Solr into a Hash matching the format that
  # CanvasJS uses
  def chartify(stats)
    datapoints = []

    # sort the stats in descending order. sorted stats is an array or arrays:
    # [[:a, 7], [:b, 6], [:c, 5], etc]
    sorted_stats = stats.sort_by {|name, count| count }.reverse

    sorted_stats[0...4].each do |stat|
      datapoints << {indexLabel: stat[0], y: (stat[1] || 0) }
    end

    # sum the counts of all the facet types that weren't in the top 4, as "Other"
    datapoints << { indexLabel: "Other", y: sorted_stats[4..-1].inject(0) {|sum, stat| sum +  stat[1]} }

    return datapoints
  end

end
