#
# Custom validator for attachments' content types
#
# @example
#
#   -> validates :image, content_type: :image
#   -> validates :image, content_type: [:jpg, :webp]
#   -> validates :image, content_type: [:image, :pdf]
#   -> validates :image, content_type: { in: :image, message: 'must be a valid image' }
#
class ContentTypeValidator < ActiveModel::EachValidator
  EXPANSIONS = {
    image:        %i[png jpeg jpg jpe pjpeg gif bmp svg webp],
    document:     %i[text txt docx doc xml pdf csv],
    calendar:     %i[ics],
    spreadsheet:  %i[xlsx xls],
    video:        %i[mpeg mpg mp3 m4a mpg4 aac webm mp4 m4v],
  }

  def validate_each(record, attribute, value)
    # Support for optional attachments
    return unless value.present? && value.attached?

    keys   = EXPANSIONS.keys
    values = EXPANSIONS.values.flatten
    options = instance_values["options"]
    message = options.try(:[], :message) || "must have a valid content type"
    types = options[:in]

    # Ensure array and ensure symbols
    types = [types].flatten.compact.map(&:to_sym)

    allowed_types = []
    types.each do |types|
      if types.in?(keys)
        allowed_types << EXPANSIONS[types]
      elsif types.in?(values)
        allowed_types << types
      else
        raise("unknown content_type types: #{types}")
      end
    end
    allowed_types = allowed_types.flatten.map(&:to_sym).uniq

    unless value.filename.extension.to_sym.in?(allowed_types)
      record.errors.add(attribute, message)
    end

  end
end
