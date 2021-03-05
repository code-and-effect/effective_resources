# HasManyRichTexts
#
# Mark your model with 'has_many_rich_texts'
# Then it will automatically create a region when using a method named rich_text_*
# object.rich_text_body = "<p>Stuff</p>"
# object.rich_text_body => ActionText::RichText<name="body" body="<p>Stuff</p>">

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

  def assign_rich_text_body(name, body)
    rich_text(name).assign_attributes(body: body)
  end

  # Prevents an ActiveModel::UnknownAttributeError
  # https://github.com/rails/rails/blob/main/activemodel/lib/active_model/attribute_assignment.rb#L48
  def respond_to?(*args)
    args.first.to_s.start_with?('rich_text_') ? true : super
  end

  def method_missing(method, *args, &block)
    super if block_given?
    super unless respond_to?(method)

    method = method.to_s
    name = method.chomp('=').sub('rich_text_', '')

    if method.end_with?('=')
      send(:assign_rich_text_body, name, *args)
    elsif args.length == 0
      send(:rich_text, name, *args)
    else
      super
    end
  end

end
