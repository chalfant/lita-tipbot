require "spec_helper"
require 'json'

describe Lita::Handlers::Tipbot, lita_handler: true do
  let(:users_list) {
    {
      'users' => [
        {'mention_name' => user.mention_name, 'email' => 'foo@bar.com' },
        {'mention_name' => 'foo', 'email' => 'bar@foo.com' }
      ]
    }
  }

  before(:each) { subject.hipchat_api = double(users_list: users_list) }

  it { is_expected.to route("tipbot register").to(:register) }
  it { is_expected.to route("tipbot address").to(:address) }
  it { is_expected.to route("tipbot balance").to(:balance) }
  it { is_expected.to route("tipbot history").to(:history) }
  it { is_expected.to route("tipbot tip @foo 10").to(:tip) }
  it { is_expected.to route("tipbot withdraw address").to(:withdraw) }
  it { is_expected.to route("tipbot make it rain").to(:make_it_rain) }
  it { is_expected.to route("tipbot make it wayne").to(:make_it_wayne) }
  it { is_expected.to route("tipbot make it blaine").to(:make_it_blaine) }
  it { is_expected.to route("tipbot make it crane").to(:make_it_crane) }
  it { is_expected.to route("tipbot make it reign").to(:make_it_reign) }

  it 'registers the user' do
    subject.tipbot_api = double(register: 'foo')
    send_message("tipbot register")
    expect(replies.first).to eq("You have been registered.")
  end

  it 'responds with the address' do
    subject.tipbot_api  = double(address: 'foo')
    send_message("tipbot address")
    expect(replies.first).to eq('foo')
  end

  it "responds with the user's balance as a string" do
    subject.tipbot_api = double(balance: 1337)
    send_message("tipbot balance")
    expect(replies.first).to eq(1337.to_s)
  end

  it "responds with the user's history" do
    history = {'foo': 0}.to_json
    subject.tipbot_api = double(history: history)
    send_message("tipbot history")
    expect(replies.first).to eq(history)
  end

  it 'submits a tip' do
    subject.tipbot_api = double(tip: '')
    send_message("tipbot tip @foo 25")
    expect(replies.first).to eq("Tip sent! Such kind shibe.")
  end

  it 'responds with withdraw address' do
    subject.tipbot_api = double(withdraw: 'foo')
    send_message("tipbot withdraw address")
    expect(replies.first).to eq('foo')
  end

  describe '#hash_email' do
    it 'hashes properly' do
      email = 'cchalfant@leafsoftwaresolutions.com'
      hash = '554976db892eff514c1bc35fbd736983'
      expect(subject.hash_email(email)).to eq(hash)
    end
  end

  describe '#active_room_members' do
    let(:room_data) {
      {
        'participants' => [
          {'id' => 1}
        ]
      }
    }
    before(:each) do
      allow(subject).to receive(:room_data).and_return(room_data)
    end

    it 'excludes users with status != available' do
      user = {
        'user' => {
          'email' => 'foo@bar.com',
          'status' => 'not_available'
        }
      }
      subject.hipchat_api = double(users_show: user)
      expect(subject.active_room_members('foo')).to be_empty
    end

    it 'excludes users in the email exclusion list' do
      user = {
        'user' => {
          'email' => 'foo@bar.com',
          'status' => 'available'
        }
      }
      subject.hipchat_api = double(users_show: user)
      allow(subject).to receive(:exclude_user?).and_return(true)
      expect(subject.active_room_members('foo')).to be_empty
    end

    it 'allows available non-excluded users' do
      user = {
        'user' => {
          'email' => 'foo@bar.com',
          'status' => 'available'
        }
      }
      subject.hipchat_api = double(users_show: user)
      allow(subject).to receive(:exclude_user?).and_return(false)
      expect(subject.active_room_members('foo').size).to eq(1)
    end
  end
end
