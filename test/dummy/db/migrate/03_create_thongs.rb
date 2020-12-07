class CreateThongs < ActiveRecord::Migration[6.0]
  def change
    create_table :thongs do |t|
      t.string :title
      t.text :body
      t.text :wizard_steps
    end
  end
end
