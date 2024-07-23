require 'httparty'
require 'json'
require 'set'

# Function to fetch and save the bibliography from multiple ORCID profiles
def fetch_and_save_bibliography(orcid_person_pairs, file_name)
  orcid_base_url = "https://pub.orcid.org/v3.0"
  crossref_base_url = "https://api.crossref.org/works"
  headers = {
    "Accept" => "application/json"
  }

  seen_dois = Set.new

  File.open(file_name, 'w') do |file|
    orcid_person_pairs.each do |orcid_id, person_id|
      # Fetch the works from the ORCID profile
      response = HTTParty.get("#{orcid_base_url}/#{orcid_id}/works", headers: headers)

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

          # Skip ArXiv versions directly
          if journal.downcase.include?("arxiv")
            puts "ArXiv version found: #{doi}. Skipping entry."
            next
          end

          # Fetch detailed work information to get authors
          authors = "Unknown Authors"
          volume = "Unknown Volume"
          pages = "Unknown Pages"

          # Fetch additional details from CrossRef using the DOI
          if doi != "Unknown DOI"
            begin
              crossref_response = HTTParty.get("#{crossref_base_url}/#{doi}", headers: headers)
            rescue HTTParty::Error => e
              puts "Failed to fetch CrossRef data for DOI: #{doi}. Error: #{e.message}"
              next
            rescue StandardError => e
              puts "An unexpected error occurred: #{e.message}"
              next
            end

            if crossref_response.success?
              crossref_data = JSON.parse(crossref_response.body)

              # Extract authors if available
              if crossref_data.dig('message', 'author')
                authors = crossref_data['message']['author'].map { |author|
                  "#{author['given']} #{author['family']}"
                }.join(" and ")
              end

              # Extract volume and pages if available
              volume = crossref_data.dig('message', 'volume') || volume
              pages = crossref_data.dig('message', 'page') || pages
            end
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
  html = {https://doi.org/#{doi}},
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
  ["0000-0003-2771-230X", "SS"],
  ["0000-0002-1678-0756", "AB"],
  ["0000-0003-1464-6999", "PB"],
  ["0000-0002-1605-8835", "FD"],
  ["0000-0001-9589-6249", "SB"],
  ["0000-0003-0574-4685", "JB"],
  ["0000-0002-5517-8389", "IR"],
  ["0000-0002-3206-424X", "AK"],
  ["0000-0002-0828-6889", "NL"],
  ["0000-0002-6741-8028", "JS"],
  ["0000-0002-1189-5116", "AZ"]
]

file_name = "bibliography.bib"
fetch_and_save_bibliography(orcid_person_pairs, file_name)