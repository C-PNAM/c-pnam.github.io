require 'httparty'
require 'json'
require 'set'

# Function to fetch and save the bibliography from multiple ORCID profiles
def fetch_and_save_bibliography(orcid_person_pairs, file_name)
  base_url = "https://pub.orcid.org/v3.0"
  headers = {
    "Accept" => "application/json"
  }

  seen_dois = Set.new

  File.open(file_name, 'w') do |file|
    orcid_person_pairs.each do |orcid_id, person_id|
      # Fetch the works from the ORCID profile
      response = HTTParty.get("#{base_url}/#{orcid_id}/works", headers: headers)

      if response.success?
        works = JSON.parse(response.body)['group']

        works.each_with_index do |work, index|
          summary = work['work-summary'].first
          title = summary['title']['title']['value']
          journal = summary['journal-title'] ? summary['journal-title']['value'] : "Unknown Journal"
          year = summary['publication-date'] ? summary['publication-date']['year']['value'] : "Unknown Year"
          ext_id = summary['external-ids']['external-id'].find { |id| id['external-id-type'] == 'doi' } rescue nil
          doi = ext_id ? ext_id['external-id-value'] : "Unknown DOI"

          # Skip this work if the DOI has already been seen and is not "Unknown DOI"
          if doi != "Unknown DOI" && seen_dois.include?(doi)
            puts "Duplicate DOI found: #{doi}. Skipping entry."
            next
          end

          # Add the DOI to the set of seen DOIs if it is known
          seen_dois.add(doi) unless doi == "Unknown DOI"

          # Fetch detailed work information to get authors, volume, and page numbers
          work_detail_response = HTTParty.get("#{base_url}/#{orcid_id}/work/#{summary['put-code']}", headers: headers)
          authors = "Unknown Authors"
          volume = "Unknown Volume"
          pages = "Unknown Pages"

          if work_detail_response.success?
            work_detail = JSON.parse(work_detail_response.body)
            contributors = work_detail.dig('contributors', 'contributor')
            if contributors
              authors = contributors.map { |contributor| contributor.dig('credit-name', 'value') }.join(", ")
            end

            volume = work_detail.dig('journal-issue', 'issue') || "Unknown Volume"
            pages = work_detail.dig('biblio', 'pages') || "Unknown Pages"
          end

          # Generate a BibTeX entry
          bibtex_entry = <<-BIBTEX
@article{work#{person_id}#{index + 1},
  author = {#{authors}},
  title = {#{title}},
  journal = {#{journal}},
  year = {#{year}},
  volume = {#{volume}},
  pages = {#{pages}},
  doi = {#{doi}},
  url = {https://doi.org/#{doi}},
  bibtex_show = {true}
}
          BIBTEX

          file.write(bibtex_entry)
        end

        puts "Bibliography entries for ORCID iD: #{orcid_id} saved to #{file_name}"
      else
        puts "Failed to fetch data for ORCID iD: #{orcid_id}"
      end
    end
  end
end

# List of ORCID iDs and corresponding person IDs
orcid_person_pairs = [
  ["0000-0003-3243-3794", "MTG"],
  ["0000-0001-5672-3310", "KM"],
  ["0000-0003-2771-230X", "SS"]
]

file_name = "bibliography.bib"
fetch_and_save_bibliography(orcid_person_pairs, file_name)