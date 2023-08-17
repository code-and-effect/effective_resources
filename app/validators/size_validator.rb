#
# Custom validator for file sizes
#
# @example
#
#   -> validates :image, size: { less_than: 2.megabytes }
#   -> validates :image, size: { less_than: 2.megabytes, message: 'is too large, please upload a file smaller than 2MB' }
#
class SizeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value.present? && value.attached?

    options = instance_values["options"]

    max_size = options.try(:[], :less_than) || 2.megabytes
    message = options.try(:[], :message) || "is too large, please upload a file smaller than #{max_size / 1.megabyte}MB"

    blobs = value.try(:blobs) || value.try(:blob) || raise('unable to find blobs')

    Array(blobs).each do |blob|
      if blob.byte_size > max_size
        record.errors.add(attribute, message)
        break
      end
    end

    true
  end
end
