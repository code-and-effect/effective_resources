class CreateThangs < ActiveRecord::Migration[6.0]
  def change
    create_table :thangs do |t|
      t.string :title
      t.text :body
    end
  end
end
