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

      # Override from wicked to support a fallback wizard step template
      def render_step(the_step, options = {}, params = {})
        if the_step.nil? || the_step.to_s == Wicked::FINISH_STEP
          redirect_to_finish_wizard(options, params)
        elsif lookup_context.exists?(the_step.to_s, lookup_context.prefixes)
          render(the_step, options)
        else
          render('effective/acts_as_wizard/wizard_step', options)
        end
      end

    end
  end
end
