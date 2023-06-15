require 'test_helper'

class ActsAsPaginableTest < ActiveSupport::TestCase
  if Post.count < (Post.default_per_page * 2)
    (Post.default_per_page * 2).times do |i|
      Post.create!(title: "New Post #{i}")
    end
  end

  test 'acts as paginable [default]' do
    assert Post.acts_as_paginable?

    # Basic test
    assert_equal Post.paginate.count, Post.default_per_page

    # Tests [page]
    assert_equal Post.paginate(page: 2).count, Post.default_per_page
    assert_equal Post.paginate(page: 3).count, 0

    # Tests [per_page]
    assert_equal Post.paginate(per_page: 1).count, 1
    assert_equal Post.paginate(per_page: 1, page: 2).count, 1

    # Tests default_per_page
    Post.default_per_page = 1
    assert_equal Post.paginate.count, Post.default_per_page
    assert_equal Post.paginate(per_page: 1).count, Post.default_per_page

    Post.default_per_page = 10
    assert_equal Post.paginate.count, Post.default_per_page
    assert_equal Post.paginate(per_page: 10).count, Post.default_per_page
  end

end
