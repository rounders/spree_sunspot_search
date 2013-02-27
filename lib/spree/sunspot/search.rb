require 'spree/core/search/base'
require 'spree/sunspot/filter/filter'
require 'spree/sunspot/filter/condition'
require 'spree/sunspot/filter/param'
require 'spree/sunspot/filter/query'

module Spree
  module Sunspot
    class Search < Spree::Core::Search::Base

      def query
        @filter_query
      end

      def solr_search
        @solr_search
      end

      def retrieve_products(*args)
        @products_scope = get_base_scope
        if args
          args.each do |additional_scope|
            case additional_scope
              when Hash
                scope_method = additional_scope.keys.first
                scope_values = additional_scope[scope_method]
                @products_scope = @products_scope.send(scope_method.to_sym, *scope_values)
              else
                @products_scope = @products_scope.send(additional_scope.to_sym)
            end
          end
        end

        curr_page = page || 1

        @products = @products_scope.includes([:master])
        Kaminari.paginate_array(@products, total_count: @solr_search.total).page(curr_page).per(per_page)
      end

      def similar_products(product, *field_names)
        products_search = ::Sunspot.more_like_this(product) do
          fields *field_names
          boost_by_relevance true
          paginate :per_page => total_similar_products * 4, :page => 1
        end

        # get active, in-stock products only.
        base_scope = get_common_base_scope
        hits = []
        if products_search.total > 0
          hits = products_search.hits.collect{|hit| hit.primary_key.to_i}
          base_scope = base_scope.where( ["#{Spree::Product.table_name}.id in (?)", hits] )
        else
          base_scope = base_scope.where( ["#{Spree::Product.table_name}.id = -1"] )
        end
        products_scope = @product_group.apply_on(base_scope)
        products_results = products_scope.includes([:images, :master]).page(1)

        # return top N most-relevant products (i.e. in the same order returned by more_like_this)
        @similar_products = products_results.sort_by{ |p| hits.find_index(p.id) }.shift(total_similar_products)
      end

      protected
      def get_base_scope
        base_scope = Spree::Product.active
        base_scope = base_scope.in_taxon(taxon) unless taxon.blank?
        base_scope = get_products_conditions_for(base_scope, keywords)
        base_scope = base_scope.on_hand unless Spree::Config[:show_zero_stock_products]

        base_scope = add_search_scopes(base_scope)
      end

      def get_products_conditions_for(base_scope, query)
        @solr_search = ::Sunspot.new_search(Spree::Product) do |q|
          q.keywords(query)

          q.order_by(
              ordering_property.flatten.first,
              ordering_property.flatten.last)
          q.paginate(page: @properties[:page] || 1, per_page: @properties[:per_page] || Spree::Config[:products_per_page])
        end

        unless @properties[:filters].blank?
          conditions = Spree::Sunspot::Filter::Query.new( @properties[:filters] )
          @solr_search = conditions.build_search( @solr_search )
        end

        @solr_search.build do |query|
          Setup.query_filters.filters.each do |filter|
            if filter.values.any? && filter.values.first.is_a?(Range)
              query.facet(filter.search_param) do
                filter.values.each do |value|
                  row(value) do
                    with(filter.search_param, value)
                  end
                end
              end
            else
              query.facet(
                  filter.search_param,
                  exclude: property_exclusion( filter.exclusion )
              )
            end

          end
        end

        @solr_search.execute
        if @solr_search.total > 0
          @hits = @solr_search.hits.collect{|hit| hit.primary_key.to_i}
          base_scope = base_scope.where( ["#{Spree::Product.table_name}.id in (?)", @hits] )
        else
          base_scope = base_scope.where( ["#{Spree::Product.table_name}.id = -1"] )
        end

        base_scope
      end

      def prepare(params)
        super
        @properties[:filters] = params[:s] || params['s'] || []
        @properties[:order_by] = params[:order_by] || params['order_by'] || []
        @properties[:total_similar_products] = params[:total_similar_products].to_i > 0 ?
            params[:total_similar_products].to_i :
            Spree::Config[:total_similar_products]
      end

      def property_exclusion(filter)
        return nil if filter.blank?
        prop = @properties[:filters].select{ |f| f == filter.to_s }
        prop[filter] unless prop.empty?
      end

      def ordering_property
        @properties[:order_by] = @properties[:order_by].empty? ? %w(score desc) : @properties[:order_by].split(',')
        @properties[:order_by].flatten
      end

    end
  end
end
