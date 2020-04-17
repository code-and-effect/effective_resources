# An ActiveRecord validator for any email field that you would use with effective_email or otherwise
#
# validates :cc, email_cc: true

class EmailCcValidator < ActiveModel::EachValidator
  PATTERN = /\A.+@.+\..+\Z/

  def validate_each(record, attribute, value)
    if value.present?
      unless value.to_s.split(',').all? { |email| PATTERN =~ email }
        record.errors.add(attribute, 'is invalid')
      end
    end
  end
end
