require 'spec_helper'

describe GenericFile do
  context 'record', :type => :feature do

    let(:user) { FactoryGirl.find_or_create :user_with_fixtures }
    let!(:file) do
      GenericFile.new.tap do |f|
        f.title = ['little_file.txt']
        f.creator = ['little_file.txt_creator']
        f.resource_type = ["Thesis" ]
        f.read_groups = ['public']
        f.abstract = "http://hydranorthdev.library.ualberta.ca/advanced"
        f.apply_depositor_metadata(user.user_key)
        f.save!
      end
    end

    after :all do
      cleanup_jetty
    end

    before do 
      sign_in user 
      visit "/files/#{file.id}"
      click_link "http://hydranorthdev.library.ualberta.ca/advanced"
    end
   
    it "should have link" do
      byebug
      expect(page).to have_content('More Search Options')
    end
    
  end
end
