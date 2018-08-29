module Effective
  module CrudController
    module Submits
      extend ActiveSupport::Concern

      module ClassMethods
        # { 'Save' => { action: save, ...}}
        def submits
          @_effective_submits ||= effective_resource.submits
        end

        # { 'Approve' => { action: approve, ...}}
        def buttons
          @_effective_buttons ||= effective_resource.buttons
        end

        # { :approve => { redirect: .. }}
        def ons
          @_effective_ons ||= effective_resource.ons
        end

        private

        def _insert_submit(action, label = nil, args = {})
          raise 'expected args to be a Hash or false' unless args.kind_of?(Hash) || args == false

          if label == false
            submits.delete_if { |label, args| args[:action] == action }; return
          end

          if args == false
            submits.delete(label); return
          end

          if label # Overwrite the default member action when given a custom submit
            submits.delete_if { |label, args| args[:default] && args[:action] == action }
          end

          if args.key?(:if) && args[:if].respond_to?(:call) == false
            raise "expected if: to be callable. Try submit :approve, 'Save and Approve', if: -> { finished? }"
          end

          if args.key?(:unless) && args[:unless].respond_to?(:call) == false
            raise "expected unless: to be callable. Try submit :approve, 'Save and Approve', unless: -> { declined? }"
          end

          if args.key?(:redirect_to) # Normalize this option to redirect
            args[:redirect] = args.delete(:redirect_to)
          end

          args[:action] = action

          (submits[label] ||= {}).merge!(args)
        end

        def _insert_button(action, label = nil, args = {})
          raise 'expected args to be a Hash or false' unless args.kind_of?(Hash) || args == false

          if label == false
            buttons.delete_if { |label, args| args[:action] == action }; return
          end

          if args == false
            buttons.delete(label); return
          end

          if label # Overwrite the default member action when given a custom label
            buttons.delete_if { |label, args| args[:default] && args[:action] == action }
          end

          if args.key?(:if) && args[:if].respond_to?(:call) == false
            raise "expected if: to be callable. Try button :approve, 'Approve', if: -> { finished? }"
          end

          if args.key?(:unless) && args[:unless].respond_to?(:call) == false
            raise "expected unless: to be callable. Try button :approve, 'Approve', unless: -> { declined? }"
          end

          if args.key?(:redirect_to) # Normalize this option to redirect
            args[:redirect] = args.delete(:redirect_to)
          end

          args[:action] = action

          (buttons[label] ||= {}).merge!(args)
        end

        def _insert_on(action, args = {})
          raise 'expected args to be a Hash or false' unless args.kind_of?(Hash) || args == false

          if args.key?(:if) && args[:if].respond_to?(:call) == false
            raise "expected if: to be callable. Try on :approve, redirect: -> { :edit }"
          end

          if args.key?(:unless) && args[:unless].respond_to?(:call) == false
            raise "expected unless: to be callable. Try on :approve, redirect: -> { :edit }"
          end

          if args.key?(:redirect_to) # Normalize this option to redirect
            args[:redirect] = args.delete(:redirect_to)
          end

          args[:action] = action

          (ons[action] ||= {}).merge!(args)
        end
      end


    end
  end
end
