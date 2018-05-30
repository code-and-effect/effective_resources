module Effective
  module FlashMessages
    extend ActiveSupport::Concern

    # flash[:success] = flash_success(@post)
    def flash_success(resource, action = nil, name: nil)
      raise 'expected an ActiveRecord resource' unless (name || resource.class.respond_to?(:model_name))

      name ||= resource.class.model_name.human.downcase

      "Successfully #{action_verb(action)} #{name}"
    end

    # flash.now[:danger] = flash_danger(@post)
    def flash_danger(resource, action = nil, e: nil, name: nil)
      raise 'expected an ActiveRecord resource' unless resource.respond_to?(:errors) && (name || resource.class.respond_to?(:model_name))

      action ||= resource.respond_to?(:new_record?) ? (resource.new_record? ? :create : :update) : :save
      action = action.to_s.gsub('_', ' ')

      name ||= resource.class.model_name.human.downcase
      messages = flash_errors(resource, e: e)

      ["Unable to #{action} #{name}", (": #{messages}." if messages)].compact.join.html_safe
    end

    # flash.now[:danger] = "Unable to accept: #{flash_errors(@post)}"
    def flash_errors(resource, e: nil)
      raise 'expected an ActiveRecord resource' unless resource.respond_to?(:errors)

      messages = resource.errors.map do |attribute, message|
        if message[0] == message[0].upcase # If the error begins with a capital letter
          message
        elsif attribute == :base
          "#{resource.class.model_name.human.downcase} #{message}"
        elsif attribute.to_s.end_with?('_ids')
          "#{resource.class.human_attribute_name(attribute.to_s[0..-5].pluralize).downcase} #{message}"
        else
          "#{resource.class.human_attribute_name(attribute).downcase} #{message}"
        end
      end

      messages << e.message if messages.blank? && e && e.respond_to?(:message)

      messages.to_sentence.presence
    end

    def action_verb(action)
      action = action.to_s.gsub('_', ' ')
      word = action.split(' ').first

      if word.end_with?('e')
        action.sub(word, word + 'd')
      else
        action.sub(word, word + 'ed')
      end
    end

  end
end
