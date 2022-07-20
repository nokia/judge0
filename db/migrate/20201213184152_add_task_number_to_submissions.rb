class AddTaskNumberToSubmissions < ActiveRecord::Migration[5.2]
  def change
    add_column :submissions, :task, :string
  end
end