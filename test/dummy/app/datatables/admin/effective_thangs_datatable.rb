class Admin::EffectiveThangsDatatable < Effective::Datatable
  datatable do

    col :id
    col :title
    col :body

    actions_col
  end

  collection do
    Effective::Thang.all
  end
end
