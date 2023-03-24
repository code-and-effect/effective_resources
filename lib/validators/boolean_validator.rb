# An ActiveRecord validator for any radio buttons or select fields with true false
#
# validates :has_credits, boolean: true

class BooleanValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.nil?
      record.errors.add(attribute, "can't be blank")
    end
  end
end
