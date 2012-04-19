class WeekLogsController < ApplicationController
  before_filter :get_week_start, :only => [:index, :add_task]
  before_filter :find_user_projects, :only => [:index, :add_task]
  before_filter :find_time_entries, :only => [:index, :add_task]
  require 'json'

  def index
    proj_cache, non_proj_cache = read_cache
    @issues = { :project_related => !proj_cache.empty? ? Issue.find(proj_cache) : Issue.open.visible.assigned_to(@user).in_projects(@projects[:non_admin]).all(:order => "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC"),
                :non_project_related => !non_proj_cache.empty? ? Issue.find(non_proj_cache) : Issue.open.visible.in_projects(@projects[:admin]).all(:order => "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC") }
    write_to_cache(@issues[:project_related].map(&:id).uniq,@issues[:non_project_related].map(&:id).uniq) 
    @issues[:project_related] = (@issues[:project_related] + @time_issues[:non_admin]).uniq
    @issues[:project_related] = sort(@issues[:project_related], params[:proj], params[:proj_dir], params[:f_tracker], params[:f_proj_name])

    @issues[:non_project_related] = (@issues[:non_project_related] + @time_issues[:admin]).uniq
    @issues[:non_project_related] = sort(@issues[:non_project_related], params[:non_proj], params[:non_proj_dir], params[:f_tracker], params[:f_proj_name])
    
    @all_project_names = (@issues[:project_related] + @issues[:non_project_related]).map {|i| i.project.name}.uniq.sort_by {|i| i.downcase}
    @tracker_names = (@issues[:project_related] + @issues[:non_project_related]).map {|i| i.tracker.name}.uniq.sort_by {|i| i.downcase}
    
    @project_names = Member.find(:all, :conditions=>["user_id=?", User.current.id]).map{|z| z.project}.uniq.select{|z| z.name !~ /admin/i && z.project_type.to_s !~ /admin/i}.map(&:name).sort_by{|i| i.downcase}
    if !@project_names.empty?
      @iter_proj = ["All Issues"] + Project.find_by_name(@project_names.first).versions.sort_by(&:created_on).reverse.map {|z| z.name}
    else
      @iter_proj = ["All Issues"]
    end
    @iter_proj.size == 1 ? @proj_issues = [] : @proj_issues = Project.find_by_name(@project_names.first).issues.select{|z| !@issues[:project_related].include?(z)}.sort_by(&:id)
    
    @non_project_names = Member.find(:all, :conditions=>["user_id=?", User.current.id]).map{|z| z.project}.uniq.select{|z| z.name.downcase['admin'] && z.project_type.to_s.downcase['admin']}.map(&:name).sort_by{|i| i.downcase}
    @non_project_names.empty? ? @non_proj_issues = [] : @non_proj_issues = Project.find_by_name(@non_project_names.first).issues.open.visible.select{|z| !@issues[:non_project_related].include?(z)}.sort_by(&:id)
    
    respond_to do |format|
      format.html
      format.json do
        render :json => @issues.to_json
      end
      format.js { render :layout => false}
    end
  end

  def update
    error_messages = {}
    error_messages[:project] = SaveWeekLogs.save(params[:project] || {}, User.current, Date.parse(params[:startdate]))
    error_messages[:non_project] = SaveWeekLogs.save(params[:non_project] || {}, User.current, Date.parse(params[:startdate]))
    render :json => error_messages.to_json
  end

  def add_task
    proj_cache, non_proj_cache = read_cache
    issues_order = "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC"
    issues = { 'project' => Issue.open.visible.in_projects(@projects[:non_admin]).all(:order => issues_order).concat(@time_issues[:non_admin]).uniq,
               'admin' => Issue.in_projects(@projects[:admin]).all(:order => issues_order).concat(@time_issues[:admin]) }
    respond_to do |format|
      format.html { redirect_to '/week_logs' }
      format.js do
        error_messages, proj_cache, non_proj_cache = SaveWeekLogs.add_task(proj_cache, non_proj_cache, issues, params)
        write_to_cache(proj_cache, non_proj_cache)
        if !error_messages.empty?
          render :text => "#{JSON error_messages.uniq}", :status => 400
        else
          head :created
        end
      end
    end
  end

  def remove_task
    proj_cache, non_proj_cache = read_cache
    respond_to do |format|
      format.html { redirect_to '/week_logs' }
      format.js do
        issue_id = params[:id].map {|x| x.to_i}
        issue_id.each do |id|
          proj_cache.delete id
          non_proj_cache.delete id
        end
        write_to_cache(proj_cache, non_proj_cache)
        head :ok
      end
    end
  end
  
  def task_search
    result = []
    existing = params[:exst]
    project = Project.find_by_name params[:project]
    iter = params[:iter]
    input = params[:search]
    iter =~ /All Issues/ ? iter = "all" : iter = project.versions.find_by_name(params[:iter]) if iter
    existing ? existing.map!{|z| Issue.find_by_id z.to_i} : []
    
    if input && input !~ /all/i
      id = input.match /(\d+)/
      subject = input.scan(/[a-zA-Z]+/).join " "
      if subject != "" # search for issue subject
        if !iter || iter == "all"
          result += project.issues.find :all, :conditions => ["subject LIKE ?", "%#{subject}%"]
        elsif iter && iter != "all"
          result += iter.fixed_issues.find :all, :conditions => ["subject LIKE ?", "%#{subject}%"]
        end
      end
      if id # search for issue id
        id = project.issues.find_by_id id[0].to_i
        result << id if id
      end
      result = result.select{|y| !existing.include?(y)}.sort_by(&:id).uniq
      params[:type] == "project" ? @proj_issues = result : @non_proj_issues = result
    elsif input && input =~ /all/i
      if params[:type] == "project" 
        if !iter || iter == "all"
          @proj_issues = project.issues.select{|y| !existing.include?(y)}.sort_by(&:id)
        elsif iter && iter != "all"
          @proj_issues = iter.fixed_issues.select{|y| !existing.include?(y)}.sort_by(&:id)
        end
      else
        @non_proj_issues = project.issues.select{|y| !existing.include?(y)}.sort_by(&:id)
      end  
    end
    
    respond_to do |format|
      format.js { render :layout => false}
    end
  end
  
  def gen_refresh
    project = Project.find_by_name params[:project]
    @non_proj_issues = project.issues.sort_by(&:id)
    existing = params[:exst]
    if existing
      existing.map!{|z| Issue.find_by_id z.to_i}
      @non_proj_issues = @non_proj_issues.select{|y| !existing.include?(y)}
    end
    respond_to do |format|
      format.js { render :layout => false}
    end
  end

  def iter_refresh
    project = Project.find_by_name params[:project]
    @iter_proj = ["All Issues"] + project.versions.sort_by(&:created_on).reverse.map {|z| z.name}
    if params[:iter]
      if params[:iter] =~ /All Issues/
        @proj_issues = project.issues.sort_by(&:id)
      else
        iter = project.versions.find(:all, :conditions => ["name = ?", params[:iter]]).first
        @proj_issues = iter.fixed_issues.sort_by(&:id)
      end
    else
      @proj_issues = project.issues.sort_by(&:id)
    end
    existing = params[:exst]
    if existing
      existing.map!{|z| Issue.find_by_id z.to_i}
      @proj_issues = @proj_issues.select{|y| !existing.include?(y)}
    end
    respond_to do |format|
      format.js { render :layout => false}
    end
  end

  private

    def write_to_cache(proj_cache, non_proj_cache)
      Rails.cache.write :project_issue_ids, proj_cache
      Rails.cache.write :non_project_issue_ids, non_proj_cache
    end

    def read_cache
      proj_cache = Rails.cache.read :project_issue_ids
      proj_cache ? proj_cache = proj_cache.dup : proj_cache = []
      non_proj_cache = Rails.cache.read :non_project_issue_ids
      non_proj_cache ? non_proj_cache = non_proj_cache.dup : non_proj_cache = [] 
      [proj_cache, non_proj_cache]
    end

    def get_week_start
      params[:week_start] == nil ? @week_start = Date.current : @week_start = Date.parse(params[:week_start])
      @week_start = @week_start.beginning_of_week
    end

    def find_user_projects
      @user = User.current
      project_related = @user.projects.select{ |project| @user.role_for_project(project).allowed_to?(:log_time) && project.name !~ /admin/i && project.project_type.to_s !~ /admin/i }
      non_project_related = @user.projects.select{ |project| @user.role_for_project(project).allowed_to?(:log_time) && project.name.downcase['admin'] && project.project_type.to_s.downcase['admin'] }
      if non_project_related.empty?
        non_project_related = @user.projects.select{ |p| @user.role_for_project(p).allowed_to?(:log_time) && p.project_type &&  p.project_type.to_s.downcase.include?("admin") && @user.member_of?(p)}.flatten.uniq
      end
      non_project_related.delete(Project.find_by_name('Exist Engineering Admin'))
      @projects = { :non_admin => project_related, :admin => non_project_related }
    end

    def find_time_entries
      @user ||= User.current
      non_proj_default = Project.find_by_name('Exist Engineering Admin')
      time_entry = TimeEntry.all(:conditions => ["spent_on BETWEEN ? AND ? AND user_id=?", @week_start, @week_start.end_of_week, @user.id])
      issues = time_entry.map(&:issue)
      proj = issues.select { |i| i.project.name !~ /admin/i && i.project.project_type.to_s !~ /admin/i }
      non_proj = issues.select { |i| i.project.project_type && i.project.project_type["Admin"]}
      non_proj += Issue.in_projects(non_proj_default) if @projects[:admin].empty?
      @time_issues = {:non_admin => proj, :admin => non_proj }
    end

    def sort(array, column, direction, tracker, proj_name)
      array = array.sort_by {|i| i.project.name.downcase}
      if column
        case column
          when 'subject' then array = array.sort_by {|i| i.id}
        end
      end
      if tracker && tracker.downcase != 'all'
        array.reject! {|i| i.tracker.name.downcase != tracker.downcase}
      end 
      if proj_name && proj_name.downcase != 'all'
        array.reject! {|i| i.project.name.downcase != proj_name.downcase}
      end
      direction == 'desc' ? array.reverse : array
    end
end
