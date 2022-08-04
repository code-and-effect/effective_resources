# frozen_string_literal: true

module Effective
  module FlashMessages
    extend ActiveSupport::Concern

    # flash[:success] = flash_success(@post)
    def flash_success(resource, action = nil, name: nil)
      raise 'expected an ActiveRecord resource' unless (name || resource.class.respond_to?(:model_name))

      name ||= if resource.respond_to?(:destroyed?) && resource.destroyed?
        resource_human_name
      else
        resource.to_s.presence || resource_human_name
      end

      "Successfully #{action_verb(action)} #{name || 'resource'}".html_safe
    end

    # flash.now[:danger] = flash_danger(@post)
    def flash_danger(resource, action = nil, e: nil, name: nil)
      raise 'expected an ActiveRecord resource' unless resource.respond_to?(:errors) && (name || resource.class.respond_to?(:model_name))

      action ||= resource.respond_to?(:new_record?) ? (resource.new_record? ? :create : :update) : :save
      action = action.to_s.gsub('_', ' ')

      messages = flash_errors(resource, e: e)

      name ||= if resource.respond_to?(:destroyed?) && resource.destroyed?
        resource_human_name
      else
        resource.to_s.presence || resource_human_name
      end

      ["Unable to #{action}", (" #{name}" if name), (": #{messages}" if messages)].compact.join.html_safe
    end

    # flash.now[:danger] = "Unable to accept: #{flash_errors(@post)}"
    def flash_errors(resource, e: nil)
      raise 'expected an ActiveRecord resource' unless resource.respond_to?(:errors)

      messages = resource.errors.map do |error|
        attribute = error.respond_to?(:attribute) ? error.attribute : error
        message = error.respond_to?(:attribute) ? error.message : resource.errors[attribute].to_sentence

        if message[0] == message[0].upcase # If the error begins with a capital letter
          message
        elsif attribute == :base
          message
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
      word = action.split(' ').first.to_s

      if word == 'destroy'
        'deleted'
      elsif word == 'undo'
        'undid'
      elsif word == 'run'
        'ran'
      elsif word.end_with?('e')
        action.sub(word, word + 'd')
      elsif ['a', 'i', 'o', 'u'].include?(word[-1])
        action
      else
        action.sub(word, word + 'ed')
      end
    end

  end
end
