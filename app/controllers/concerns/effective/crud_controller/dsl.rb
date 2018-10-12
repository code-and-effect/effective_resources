module Effective
  module CrudController
    module Dsl

      # https://github.com/rails/rails/blob/v5.1.4/actionpack/lib/abstract_controller/callbacks.rb
      def before_render(*names, &blk)
        _insert_callbacks(names, blk) { |name, options| set_callback(:resource_render, :before, name, options) }
      end

      def before_save(*names, &blk)
        _insert_callbacks(names, blk) { |name, options| set_callback(:resource_before_save, :after, name, options) }
      end

      def after_save(*names, &blk)
        _insert_callbacks(names, blk) { |name, options| set_callback(:resource_after_save, :after, name, options) }
      end

      def after_error(*names, &blk)
        _insert_callbacks(names, blk) { |name, options| set_callback(:resource_error, :after, name, options) }
      end

      # This controls the form submit options of effective_submit
      # Takes precidence over any 'on' dsl commands
      #
      # Effective::Resource will populate this with all crud actions
      # And you can control the details with this DSL:
      #
      # submit :approve, 'Save and Approve', unless: -> { resource.approved? }, redirect: :show
      #
      # submit :toggle, 'Blacklist', if: -> { sync? }, class: 'btn btn-primary'
      # submit :toggle, 'Whitelist', if: -> { !sync? }, class: 'btn btn-primary'
      # submit :save, 'Save', success: -> { "#{resource} was saved okay!" }
      def submit(action, label = nil, args = {})
        _insert_submit(action, label, args)
      end

      # This controls the resource buttons section of the page
      # Takes precidence over any on commands
      #
      # Effective::Resource will populate this with all member_actions
      #
      # button :approve, 'Approve', unless: -> { resource.approved? }, redirect: :show
      # button :decline, false
      def button(action, label = nil, args = {})
        _insert_button(action, label, args)
      end

      # This is a way of defining the redirect, flash etc of any action without tweaking defaults
      # submit and buttons options will be merged ontop of these
      def on(action, args = {})
        _insert_on(action, args)
      end

      # page_title 'My Title', only: [:new]
      def page_title(label = nil, opts = {}, &block)
        opts = label if label.kind_of?(Hash)
        raise 'expected a label or block' unless (label || block_given?)

        instance_exec do
          before_action(opts) { @page_title ||= (block_given? ? instance_exec(&block) : label).to_s }
        end
      end

      # resource_scope -> { current_user.things }
      # resource_scope -> { Thing.active.where(user: current_user) }
      # resource_scope do
      #   { user_id: current_user.id }
      # end
      # Nested controllers? sure
      # resource_scope -> { User.find(params[:user_id]).things }

      # Return value should be:
      # a Relation: Thing.where(user: current_user)
      # a Hash: { user_id: current_user.id }
      def resource_scope(obj = nil, opts = {}, &block)
        raise 'expected a proc or block' unless (obj.respond_to?(:call) || block_given?)

        instance_exec do
          before_action(opts) { @_effective_resource_scope ||= instance_exec(&(block_given? ? block : obj)) }
        end
      end

    end
  end
end
