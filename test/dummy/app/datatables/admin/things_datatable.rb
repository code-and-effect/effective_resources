class Admin::ThingsDatatable < Effective::Datatable
  datatable do

    col :id
    col :title
    col :body

    actions_col
  end

  collection do
    Thing.all
  end
end
