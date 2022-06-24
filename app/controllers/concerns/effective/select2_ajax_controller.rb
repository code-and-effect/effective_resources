module Effective
  module Select2AjaxController
    extend ActiveSupport::Concern

    def respond_with_select2_ajax(collection, skip_search: false, &block)
      raise('collection should be an ActiveRecord::Relation') unless collection.kind_of?(ActiveRecord::Relation)

      # Authorize
      EffectiveResources.authorize!(self, :index, collection.klass)

      # Scope
      if collection.respond_to?(:select2_ajax)
        collection = collection.select2_ajax
      elsif collection.respond_to?(:sorted)
        collection = collection.sorted
      end

      # Search
      if (term = params[:term]).present? && !skip_search
        collection = Effective::Resource.new(collection).search_any(term)
      end

      # Paginate
      per_page = 50
      page = (params[:page] || 1).to_i
      last = (collection.reselect(:id).count.to_f / per_page).ceil
      more = page < last

      offset = [(page - 1), 0].max * per_page
      collection = collection.limit(per_page).offset(offset)

      # Results
      results = collection.map do |resource|
        if block_given?
          option = yield(resource)
          raise('expected a Hash with id and text params') unless option.kind_of?(Hash) && option[:id] && option[:text]
          option
        else
          { id: resource.to_param, text: resource.try(:to_select2) || resource.to_s }
        end
      end

      # Respond
      respond_to do |format|
        format.js do
          render json: { results: results, pagination: { more: more } }
        end
      end
    end

  end
end
