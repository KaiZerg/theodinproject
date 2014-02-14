require 'spec_helper'

# This spec combines both the courses and the lessons into one since they're so tightly intertwined
# Particularly because you need to create a course to create a section to create a lesson
# At some point we should probably refactor this out into separate specs and build a factory script
# that, if you want to create a Lesson, will automatically create a Section and Course for you.

describe "Courses and Lessons Pages" do

  subject {page}

  before do
    courses = FactoryGirl.create_list(:course, 3, :is_active => true)
    courses += FactoryGirl.create_list(:course, 4, :is_active => false)
    sections = []
    courses.each do |course|
      5.times do
        sections << FactoryGirl.create(:section, :course_id => course.id)
      end
    end
    sections.each do |section|
      2.times{FactoryGirl.create(:lesson, :section_id => section.id)}
      2.times{FactoryGirl.create(:lesson, :section_id => section.id, :is_project => true)}
    end
  end

  context "on the courses page" do

    before do
      visit courses_path
    end

    it { should have_selector("h1", :text => "This is Your Path to Learning Web Development") }

    describe "it should include every course" do

      it "by title" do
        Course.all.each do |course|
          subject.should have_selector("h2", :text => course.title)
        end
      end
      # make it a controller test for the orderings
    end
    context "for inactive courses" do
      it "should say 'coming soon'" do
        course = Course.where(:is_active => false).first
        subject.should have_selector("h2", :text => "#{course.title} ...Coming Soon!")
      end
    end
    context "for regular lessons" do
      it "should not say Coming Soon" do
        course = Course.where(:is_active => true).first
        subject.should_not have_selector("h2", :text => "#{course.title} ...Coming Soon!")
      end
    end
  end

  context "on the lessons index page" do

    let(:course1) { Course.first }

    before do
      visit course_path(course1.title_url)
    end

    it "should include every lesson for that course" do
      course1.lessons.each do |lesson|
        subject.should have_selector("h3", :text => lesson.title)
      end
    end

    it "should not include lessons for any other course" do
      not_included_lesson = Course.where("id != #{course1.id}").first.lessons.first
      # puts not_included_lesson.inspect
      subject.should_not have_selector("h3", :text => not_included_lesson.title)
    end

    it "should include all sections for that course" do
      course1.sections.each do |section|
        subject.should have_selector("h2", :text => section.title)
      end
    end

    it "should not include all sections for another course" do
      not_included_section = Course.where("id != #{course1.id}").first.sections.first
      # puts not_included_section.inspect
      subject.should_not have_selector("h3", :text => not_included_section.title)
    end

    context "for projects" do

      let(:project1) { course1.lessons.where(:is_project => :true).first }

      it "should have a special project class" do
        project1.title.should_not be_blank
        url = lesson_path(course1.title_url, project1.title_url)
        # save_and_open_page
        xpath = "//a[@href=\'#{url}\']//*[@class='lesson project']"
        subject.should have_xpath(xpath)
        # subject.find(:xpath, xpath).text.should == "Project:"
      end
    end

    context "for regular lessons" do
      
      let(:non_project1) { course1.lessons.where(:is_project => :false).first }

      it "should not have a special project class" do
        non_project1.title.should_not be_blank
        url = lesson_path(course1.title_url, non_project1.title_url)
        xpath = "//a[@href=\'#{url}\']//*[@class='lesson project']"
        subject.should_not have_xpath(xpath)
      end
    end
  end

  context "in the individual lesson page" do

    let!(:course1) { Course.first }
    let!(:lesson1) { course1.lessons.where(:is_project => false).first }
    let!(:project1) { course1.lessons.where(:is_project => :true).first }
    let!(:non_project1) { course1.lessons.where(:is_project => :false).first }

    before do
      visit lesson_path(course1.title_url, lesson1.title_url)
    end

    it "should show the lesson name in the title" do
      subject.source.should have_selector('title', text: lesson1.title)
    end

    it "should show something in the lesson body container" do
      subject.find(:xpath,"//*[@class='individual-lesson ']//*[@class='container']").text.should_not be_empty
    end

    context "for projects" do
      before do
        visit lesson_path(course1.title_url, project1.title_url)
      end

      it "should have a special project class" do
        xpath = "//*[@class='individual-lesson project-lesson']"
        subject.should have_xpath(xpath)
      end
    end

    context "for regular lessons" do
      before do
        visit lesson_path(course1.title_url, non_project1.title_url)
      end

      it "should not have a special project class" do
        xpath = "//*[@class='individual-lesson project-lesson']"
        subject.should_not have_xpath(xpath)
      end
    end

    describe "navigation buttons and links" do
      
      # use the second section so we don't overlap with the 
      # whole curriculum tests
      let(:second_section) { Section.all[1] }
      let(:first_sec_lesson){ second_section.lessons.order("position asc").first }
      let(:second_sec_lesson){ second_section.lessons.order("position asc")[1] }
      let(:last_sec_lesson){ second_section.lessons.order("position asc").last }
      let(:next_last_sec_lesson){ second_section.lessons.order("position asc")[-1] }
      let(:next_sec_first_lesson) { Section.all[2].lessons.order("position asc").first}

      # very first lesson of a course
      let(:first_lesson){ Lesson.order("position asc").first }
      # very last lesson of a course
      let(:last_lesson){ first_lesson.course.lessons.order("position asc").last }

      it "should be a valid section size" do
        second_section.lessons.count.should >= 4
      end

      it "should have a backlink to the lessons list" do
        subject.should have_xpath("//*[@href = \'#{lessons_path(course1.title_url)}\']")
      end
      
      context "in the middle of a section" do
        before do
          visit lesson_path(first_sec_lesson.course.title_url, first_sec_lesson.title_url)
        end
        it "should show a next button for the next course" do
          # save_and_open_page
          subject.should have_xpath("//*[@href = \'#{lesson_path(second_sec_lesson.course.title_url, second_sec_lesson.title_url)}\']")
        end
        it "should have backlinks to the courses directory" do
          subject.should have_link("Course List", :href => courses_path)
        end
      end

      context "at the end of a section" do
        before do
          visit lesson_path(last_sec_lesson.course.title_url, last_sec_lesson.title_url)
        end
        it "should show a next button to next section's first course" do
          subject.should have_xpath("//*[@href = \'#{lesson_path(next_sec_first_lesson.course.title_url, next_sec_first_lesson.title_url)}\']")
        end
      end

      context "at the beginning of a course" do
        before do
          visit lesson_path(first_lesson.course.title_url, first_lesson.title_url)
        end
        it "should not show a backlink to the previous lesson" do 
          subject.should_not have_link("Previous")
        end
      end

      context "at the end of a course" do
        before do
          visit lesson_path(last_lesson.course.title_url, last_lesson.title_url)
        end

        it "should show the modified next button" do
          subject.should have_selector("button", :text => "View the Courses Index")
        end
      end
    end

    describe "End-of-lesson checkbox section" do
      it "should be there" do
        expect(page).to have_css(".completion-wrapper")
      end
    end

    context "for logged in students" do
      
      let!(:signed_in_student){ FactoryGirl.create(:user) }

      before do
        sign_in(signed_in_student)
      end
      
      context "after visiting an individual lesson" do
        
        before do
          visit lesson_path(course1.title_url, lesson1.title_url)
        end
        
        describe "End-of-lesson checkbox section" do
          
          let!(:completion_wrapper_div){ ".completion-wrapper" }
          
          it "shouldn't have a link to sign in" do
            within(completion_wrapper_div) do
              expect(page).to_not have_link("", :href => login_path)
            end
          end
          
          context "if user hasn't yet completed the lesson" do
            # (default state)
            
            it "should have text for marking lesson completed" do
              within(completion_wrapper_div) do
                expect(page).to have_text("Mark Lesson Completed")
              end
            end
            it "should have a link (the checkbox) to mark a lesson completed" do
              within(completion_wrapper_div) do
                expect(page).to have_css("a.lc-unchecked")
              end
            end
            
            context "after clicking the complete lesson box" do
              
              # model creates a lesson_completion instance
              it "should create a lesson_completion instance (JS test)", :js => true do
                expect {
                  find("a.lc-unchecked").click
                  }.to change(LessonCompletion, :count).by(1)
              end
              
              # After the AJAX returns, it should re-render just the checkbox area to reflect
              # the completed checkbox and add a link to un-complete the lesson
              # Note: this test was created in Nitrous.io so it couldn't be run!
              it "should change the form's class to reflect completion (JS test)", :js => true do
                find(".action-complete-lesson").click
                expect(page).to have_css("a.lc-uncomplete-link") 
              end
            end
          end
          
          context "if the user has already completed the lesson" do
            
            before do
              @lc = LessonCompletion.create(:lesson_id => lesson1.id, :student_id => signed_in_student.id)
              puts signed_in_student.inspect
              puts "LESSON ID #{lesson1.id}!"
              puts "LC itself is #{@lc}!"
              puts "LC ID #{@lc.inspect}!"
              visit lesson_path(course1.title_url, lesson1.title_url)
            end
            
            it "should have a link for marking lesson NOT completed" do
              #puts page.html
              expect(page).to have_css(".lc-uncomplete-link")
            end
            
            context "after clicking the 'mark lesson not completed' link" do
              # model destroys the lesson_completion instance
              it "should destroy the lesson_completion instance (JS test)", :js => true do
                expect {
                  find(".lc-uncomplete-link").click
                  }.to change(LessonCompletion, :count).by(-1)
              end
            end
          end
        end
      end
      context "after visiting the lessons index page (a course page)" do
        
        before do
          visit lesson_path(course1.title_url, lesson1.title_url)
        end

        it "should have a checkbox for the lesson" do
          
          expect(page).to have_css("#lc-id-#{lesson1.id}")
          
        end
        
        
        context "when user has not already completed the lesson" do
          
          context "when there are two lessons on the page" do
            
            # checking one doesn't check both
            
          end
          
          it "the lesson's checkbox should appear unchecked" do
            
            #within("") do
            #  expect(page).to have_css(".some-lesson.lc-unchecked")
            #end
            
          end
          
          context "after clicking the checkbox" do
            
            it "should update the database with a new lesson_completion" do
              
            end
            
            it "should change the checkbox to unchecked" do
              
            end
            
          end
          
        end
        
        context "and user HAS already completed the lesson" do
          
          it "should show a checked box for that lesson" do
            
          end
          
          context "after clicking that checked box" do
            
            it "should remove the lesson_completion from the database" do
              
            end
            
            it "should change the checkbox to its unchecked state" do
              
            end
            
          end
          
        end
        
      end
        
    end
    context "for not logged in visitors" do
      
      describe "End-of-lesson checkbox section" do
        
        let!(:completion_wrapper_div){ ".completion-wrapper" }        
        
        it "should contain a link to sign in" do
          within(completion_wrapper_div) do
            expect(page).to have_link("", :href => login_path)
          end
        end
        
        it "should have text for marking lesson completed" do
          within(completion_wrapper_div) do
            expect(page).to have_text("Mark Lesson Completed")
          end
        end
        
        it "should NOT have a link (the checkbox) to mark a lesson completed" do
          within(completion_wrapper_div) do
            expect(page).to_not have_css("a.action-complete-lesson")
          end
        end
      end
    end
  end
end