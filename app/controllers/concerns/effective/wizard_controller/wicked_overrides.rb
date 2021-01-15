module Effective
  module WizardController
    module WickedOverrides

      # Changes made here to work inside an effective rails engine
      #
      # https://github.com/zombocom/wicked/blob/main/lib/wicked/controller/concerns/path.rb
      # https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/routing/url_for.rb#L180
      def wizard_path(goto_step = nil, options = {})
        options = options.respond_to?(:to_h) ? options.to_h : options
        options = { :controller => wicked_controller,
                    :action     => 'show',
                    :id         => goto_step || params[:id],
                    :only_path  => true
                   }.merge(options)

        merged_url_options = options.reverse_merge!(url_options)
        effective_resource.url_helpers.url_for(merged_url_options)
      end

    end
  end
end
