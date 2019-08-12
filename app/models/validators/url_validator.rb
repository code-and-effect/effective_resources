# An ActiveRecord validator for any url field that you would use with effective_url or otherwise
#
# validates :website, url: true

class UrlValidator < ActiveModel::EachValidator
  PATTERN = /\Ahttps?:\/\/\w+.+\Z/

  def validate_each(record, attribute, value)
    if value.present?
      record.errors.add(attribute, 'is invalid') unless PATTERN =~ value
    end
  end
end
