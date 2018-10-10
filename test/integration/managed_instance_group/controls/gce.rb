# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

project_id = attribute('project_id')
instance_template_link = attribute('instance_template_link')
instance_template_name = instance_template_link.split("/").last
network = attribute('network')
subnetwork = attribute('subnetwork')
image = attribute('image')
machine_type = attribute('machine_type')
vm_container_label = attribute('vm_container_label')

control "gce" do
  title "Google Compute Engine MIG configuration"

  describe command("gcloud --project=#{project_id} compute instance-templates describe #{instance_template_name} --format json") do
    its('exit_status') { should be 0 }
    its('stderr') { should eq '' }

    let!(:metadata) do
      if subject.exit_status == 0
        JSON.parse(subject.stdout)['properties']
      else
        {}
      end
    end

    let(:container_declaration) do
      YAML.load(metadata['metadata']['items'].select { |h| h['key'] == 'gce-container-declaration' }.first['value'].gsub("\t", "  "))
    end

    it "is in the correct network" do
      expect(metadata['networkInterfaces'][0]['network']).to end_with network
    end

    it "is in the correct subnetwork" do
      expect(metadata['networkInterfaces'][0]['subnetwork']).to end_with subnetwork
    end

    it "is the expected machine type" do
      expect(metadata['machineType']).to end_with machine_type
    end

    it "has the expected labels" do
      expect(metadata['labels'].keys).to include "container-vm"
      expect(metadata['labels']['container-vm']).to eq vm_container_label
    end

    it "is configured with the expected container(s), volumes, and restart policy" do
      expect(container_declaration).to eq({
        "spec" => {
          "containers" => [
            {
              "image" => image,
            },
          ],
          "restartPolicy" => "OnFailure",
          "volumes" => [],
        },
      })
    end
  end
end
