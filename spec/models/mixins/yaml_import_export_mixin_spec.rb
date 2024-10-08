RSpec.describe YamlImportExportMixin do
  let(:test_class) { Class.new { include YamlImportExportMixin } }

  before do
    @report1 = FactoryBot.create(:miq_report, :name => "test_report_1")
  end

  context ".export_to_array" do
    before  { @klass = MiqReport }
    subject { test_class.export_to_array(@list, @klass) }

    it "invalid class" do
      @list, @klass = [12345], "xxx"
      expect(subject).to eq([])
    end

    it "invalid instance" do
      @list = [12345]
      expect(subject).to eq([])
    end

    it "single valid instance" do
      policy = FactoryBot.create(:miq_policy, :name => "test_policy")
      @list = [@report1.id, policy.id]

      expect_any_instance_of(MiqPolicy).to receive(:export_to_array).never
      expect_any_instance_of(MiqReport).to receive(:export_to_array).once
      subject
    end

    it "multiple valid instances" do
      @report2 = FactoryBot.create(:miq_report, :name => "test_report_2")
      @list = [@report1.id, @report2.id]

      expect(subject.size).to eq(2)
    end
  end

  it ".export_to_yaml" do
    expect(test_class).to receive(:export_to_array).once.with([@report1.id], MiqReport)
    test_class.export_to_yaml([@report1.id], MiqReport)
  end

  context ".import" do
    subject { MiqReport }

    it "valid YAML file" do
      fd = StringIO.new("---\n- MiqReport:\n")
      # if it gets to import_from_array, then it did not choke on yml
      expect(subject).to receive(:import_from_array)
      subject.import(fd)
    end

    it "invalid YAML file" do
      fd = StringIO.new("---\na:\nb")
      expect { subject.import(fd) }.to raise_error("Invalid YAML file")
    end

    it "invalid YAML file for hacked payloads" do
      fd = StringIO.new(<<~YAML)
        ---
        - !ruby/object:Gem::Installer
            i: x
        - !ruby/object:Gem::SpecFetcher
            i: y
        - !ruby/object:Gem::Requirement
          requirements:
            !ruby/object:Gem::Package::TarReader
            io: &1 !ruby/object:Net::BufferedIO
              io: &1 !ruby/object:Gem::Package::TarReader::Entry
                read: 0
                header: "abc"
              debug_output: &1 !ruby/object:Net::WriteAdapter
                socket: &1 !ruby/object:PrettyPrint
                  output: !ruby/object:Net::WriteAdapter
                    socket: &1 !ruby/module 'Kernel'
                    method_id: :eval
                  newline: FactoryBot.create(:miq_report, :name => "hacked")
                  buffer: {}
                  group_stack:
                  - !ruby/object:PrettyPrint::Group
                    break: true
                method_id: :breakable
      YAML

      expect { subject.import(fd) }.to raise_error("Invalid YAML file")

      expect(subject.where(:name => "hacked")).to_not exist
    end
  end

  context ".validate_import_data_class" do
    subject { MiqReport }

    it "confirms valid class" do
      @data = YAML.safe_load(StringIO.new("---\n- MiqReport:\n").read)
      expect { subject.validate_import_data_class(@data) }.not_to raise_error
    end

    it "raises exception on invalid class" do
      @data = YAML.safe_load(StringIO.new("---\n- MiqWidget:\n").read)
      expect { subject.validate_import_data_class(@data) }.to raise_error("Incorrect format: Expected MiqReport and received MiqWidget.")
    end
  end
end
