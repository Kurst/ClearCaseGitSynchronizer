=begin
Class for executing basic git commands in ruby scripts. 

@Author:      Semerhanov Ilya
@Date:        12.01.2013
@Last Update: 27.04.2013
@Company:     T-Systems CIS
=end

module Git
class GitWrapper

  def initialize repo
    @git_repo = repo
  end

  def init
    IO.popen("git --git-dir=#{@git_repo} init") { |f| puts f.gets }
  end

  def get_modified_files(tag1, tag2, filename)

    IO.popen("git --git-dir=#{@git_repo} log #{tag1}..#{tag2} --diff-filter=M --name-only --pretty=format:\"Submitter: %an || Comment: %s\" | tee #{filename}") { |f|
      puts "List of modified files:"
      while (line = f.gets) do
        puts line
      end
      puts
    }

  end

  def get_added_files(tag1, tag2, filename)
    IO.popen("git --git-dir=#{@git_repo} log #{tag1}..#{tag2} --diff-filter=A --name-only --pretty=format:\"Submitter: %an || Comment: %s\" | tee #{filename}") { |f|
      puts "List of added files:"
      while (line = f.gets) do
        puts line
      end
      puts
    }

  end

  def get_deleted_files(tag1, tag2, filename)
    IO.popen("git --git-dir=#{@git_repo} log #{tag1}..#{tag2} --diff-filter=D --name-only --pretty=format:\"Submitter: %an || Comment: %s\" | tee #{filename}") { |f|
      puts "List of deleted files:"
      while (line = f.gets) do
        puts line
      end
      puts
    }

  end

  def create_tag(tag)
    IO.popen("git --git-dir=#{@git_repo} tag #{tag}") { |f|
      puts "New tag: #{tag}"
      puts f.gets

    }
  end

  def get_previous_tag(branch)

    IO.popen("git --git-dir=#{@git_repo} tag -l |grep #{branch} |tail -n 2|head -n 1") { |f|
       res = f.gets
       return res.chomp
    }

  end

  def extract_file(path, branch, output)
    IO.popen("git --git-dir=#{@git_repo} archive #{branch}: #{path} | tar -x -C #{output}/") { |f|
      puts "Extracting file #{path}..."
      f.gets
    }
  end

  def clone(folder, url)
    IO.popen("git clone #{url} #{folder}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
    IO.popen("git --git-dir=#{folder} config --global user.name \"gitserver\"") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
    IO.popen("git --git-dir=#{folder} config --global user.email \"gitserver@localhost\"") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }

  end

  def create_branch(repo, name)
    IO.popen("cd #{repo};git branch #{name}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def switch_branch(repo, name)
    IO.popen("cd #{repo};git checkout #{name}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def remove_branch(repo, name)
    IO.popen("cd #{repo};git branch -D #{name}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def add(repo, file)
    IO.popen("cd #{repo};git add -A #{file}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def commit(repo, commit_msg, user)
    IO.popen("cd #{repo};git config --global user.name \"#{user}\"") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
    regex = /TM[A-Z][a-z]{2}(\d){5}(\s(.*)|$)/

    if !regex.match(commit_msg)
      commit_msg = "TMOad01515 #{commit_msg}"
    end

    IO.popen("cd #{repo};git commit -m \"#{commit_msg} *Synchronizer*\"") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def merge(repo, branch)
    IO.popen("cd #{repo};git merge #{branch}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def push(repo, branch)
    IO.popen("cd #{repo};git push origin #{branch}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def pull_rebase(repo, branch)
    IO.popen("cd #{repo};git pull --rebase origin #{branch}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def push_remote(remote)

    IO.popen("git --git-dir=#{@git_repo} push #{remote}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def checkout_remote(repo, branch)
    if branch != 'master'
      IO.popen("cd #{repo};git checkout -b #{branch} origin/#{branch}") { |f|
        while (line = f.gets) do
          puts line
        end
        puts
      }
    end
  end

  def switch_bare_branch(branch)
    sleep 2
    IO.popen("git --git-dir=#{@git_repo} symbolic-ref HEAD refs/heads/#{branch}") { |f|
      puts "Switched branch in bare repo to #{branch}..."
      f.gets
    }
  end

  def update_index(repo, path)
    IO.popen("cd #{repo};git add -u #{path}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def add_to_index(repo, path)
    IO.popen("cd #{repo};git add #{path}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def rm(repo, path)
    IO.popen("cd #{repo};git rm #{path}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def reset_hard(repo, commit)
    IO.popen("cd #{repo};git reset --hard #{commit}") { |f|
      while (line = f.gets) do
        puts line
      end
      puts
    }
  end

  def get_head_id(repo)
    IO.popen("cd #{repo};git rev-parse HEAD") { |f|
      return f.gets
    }
  end

  def update_commiter_name(repo, commit)
    IO.popen("cd #{repo}; git filter-branch --env-filter 'GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME; export GIT_COMMITTER_NAME' #{commit.chomp}..HEAD") { |f|
      return f.gets
    }
  end

  def abort_rebase(repo)
    IO.popen("cd #{repo}; git rebase --abort") { |f|
      return f.gets
    }
  end

end
end