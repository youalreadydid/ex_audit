defmodule AssocTest do
  use ExUnit.Case

  import Ecto.Query

  alias ExAudit.Test.{Repo, User, Version, BlogPost, Comment, Util}

  test "comment lifecycle tracked" do
    user = Util.create_user()

    ExAudit.track(actor_id: user.id)

    params = %{
      title: "Controversial post",
      author_id: user.id,
      comments: [
        %{
          body: "lorem impusdrfnia",
          author_id: user.id
        }
      ]
    }

    changeset = BlogPost.changeset(%BlogPost{}, params)
    {:ok, %{comments: [comment]} = blog_post} = Repo.insert(changeset)

    [%{actor_id: actor_id}] = comment_history = Repo.history(comment)
    assert length(comment_history) == 1
    assert actor_id == user.id
  end

  test "should track cascading deletions (before they happen)" do
    user = Util.create_user()

    ExAudit.track(actor_id: user.id)

    params = %{
      title: "Controversial post",
      author_id: user.id,
      comments: [
        %{
          body: "lorem impusdrfnia",
          author_id: user.id
        }, %{
          body: "That's a nice article",
          author_id: user.id
        }, %{
          body: "We want more of this CONTENT",
          author_id: user.id
        }
      ]
    }

    changeset = BlogPost.changeset(%BlogPost{}, params)
    {:ok, %{comments: comments} = blog_post} = Repo.insert(changeset)

    Repo.delete(blog_post)

    comment_ids = Enum.map(comments, &(&1.id))

    versions = Repo.all(from v in Version,
      where: v.entity_id in ^comment_ids,
      where: v.entity_schema == ^Comment)

    assert length(versions) == 6 # 3 created, 3 deleted
  end
end