require 'httparty'
require 'json'

# Function to fetch and save the bibliography from an ORCID profile
def fetch_and_save_bibliography(orcid_id, file_name)
  base_url = "https://pub.orcid.org/v3.0"
  headers = {
    "Accept" => "application/json"
  }

  # Fetch the works from the ORCID profile
  response = HTTParty.get("#{base_url}/#{orcid_id}/works", headers: headers)

  if response.success?
    works = JSON.parse(response.body)['group']

    File.open(file_name, 'w') do |file|
      works.each_with_index do |work, index|
        summary = work['work-summary'].first
        title = summary['title']['title']['value']
        journal = summary['journal-title'] ? summary['journal-title']['value'] : "Unknown Journal"
        year = summary['publication-date'] ? summary['publication-date']['year']['value'] : "Unknown Year"
        ext_id = summary['external-ids']['external-id'].find { |id| id['external-id-type'] == 'doi' } rescue nil
        doi = ext_id ? ext_id['external-id-value'] : "Unknown DOI"

        # Generate a BibTeX entry
        bibtex_entry = <<-BIBTEX
@article{work#{index + 1},
  title = {#{title}},
  journal = {#{journal}},
  year = {#{year}},
  doi = {#{doi}},
  html = {https://doi.org/#{doi}},
  bibtex_show={true}
}
        BIBTEX

        file.write(bibtex_entry)
      end
    end

    puts "Bibliography saved to #{file_name}"
  else
    puts "Failed to fetch data for ORCID iD: #{orcid_id}"
  end
end

# Replace this with the ORCID iD you want to query
orcid_id = "0000-0003-3243-3794"
file_name = "_bibliography/bibliography.bib"
fetch_and_save_bibliography(orcid_id, file_name)