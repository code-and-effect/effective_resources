# HasManyRichTexts
#
# Mark your model with 'has_many_rich_texts' and then any method missing is a rich text region

module HasManyRichTexts
  extend ActiveSupport::Concern

  module Base
    def has_many_rich_texts(options = nil)
      include ::HasManyRichTexts
    end
  end

  included do
    has_many :rich_texts, class_name: 'ActionText::RichText', as: :record, inverse_of: :record, dependent: :destroy
    accepts_nested_attributes_for :rich_texts, allow_destroy: true
  end

  module ClassMethods
  end

  # Find or build
  def rich_text(name)
    name = name.to_s
    rich_texts.find { |rt| rt.name == name } || rich_texts.build(name: name)
  end

  def rich_text_body=(name, body)
    rich_text(name).assign_attributes(body: body)
  end

  # Prevents an ActiveModel::UnknownAttributeError
  # https://github.com/rails/rails/blob/main/activemodel/lib/active_model/attribute_assignment.rb#L48
  def respond_to?(*args)
    method = args.first.to_s
    return false if ['to_a', 'to_ary'].any? { |str| method == str }
    return false if ['_by', '_at', '_id', '_by=', '_at=', 'id='].any? { |str| method.end_with?(str) }
    true
  end

  def method_missing(method, *args, &block)
    super if block_given?
    super unless respond_to?(method)

    method = method.to_s

    if method.end_with?('=') && args.length == 1 && (args.first.kind_of?(String) || args.first.kind_of?(NilClass))
      send(:rich_text_body=, method.chomp('='), *args)
    elsif args.length == 0
      send(:rich_text, method, *args)
    else
      super
    end
  end

end
