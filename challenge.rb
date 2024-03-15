require 'json'
require 'set'

BOOLEAN_SET = Set[true, false]
INDENT_SIZE = 4
OUTPUT_FILENAME = 'output.txt'

# utils

# returns hash
def parse_json_file(filepath)
    JSON.parse(File.read(filepath))
rescue JSON::ParserError => e
    puts "Error parsing JSON file `#{filepath}`: #{e.message}"
    {}
end

def indent_string(string, indent_count)
    "#{' ' * INDENT_SIZE * indent_count}#{string}"
end

def valid_data?(data, schema)
    data.is_a?(Hash) && data.length == schema.length &&
    schema.all? do |key, type|
        data.include?(key) && 
            type == BOOLEAN_SET ? type.include?(data[key]) : data[key].is_a?(type)
    end
end

# helpers

def _send_top_up_email(email_address, new_token_balance)
    # send the email!
end

def _valid_companies?(companies)
    return false unless companies.is_a?(Array)

    schema = {
        "id" => Integer,
        "name" => String,
        "top_up" => Integer,
        "email_status" => BOOLEAN_SET
    }

    companies.all? { |company| valid_data?(company, schema) }
end

def _valid_users?(users)
    return false unless users.is_a?(Array)

    schema = {
        "id" => Integer,
        "first_name" => String,
        "last_name" => String,
        "email" => String,
        "company_id" => Integer,
        "email_status" => BOOLEAN_SET,
        "active_status" => BOOLEAN_SET,
        "tokens" => Integer
    }

    users.all? { |user| valid_data?(user, schema)}
end

def top_up_many(users, companies)
    companies_by_id = companies.map { |company| [company['id'], company] }.to_h

    valid_users = users.select do |user|
        user['active_status'] && companies_by_id.include?(user['company_id'])
    end
    .sort_by { |user| [user['last_name'], user['first_name'], user['email']] }

    users_by_company_id = valid_users.group_by { |user| user['company_id'] }

    users_by_company_id.keys.sort
    .map do |company_id|
        users = users_by_company_id[company_id]
        company = companies_by_id[company_id]
        users_emailed = []
        users_not_emailed = []

        users.each do |user|
            previous_token_balance = user['tokens']
            new_token_balance = previous_token_balance + company['top_up']
            updated_user = user.merge('tokens' => new_token_balance)

            user_data = {
                'user' => updated_user,
                'previous_token_balance' => previous_token_balance,
                'new_token_balance' => new_token_balance
            }

            if company['email_status'] && user['email_status']
                _send_top_up_email(user['email'], new_token_balance)
                users_emailed << user_data
            else
                users_not_emailed << user_data
            end
        end

        {
            'company' => company,
            'users_emailed' => users_emailed,
            'users_not_emailed' => users_not_emailed,
            'total_top_ups' => company['top_up'] * users.length
        }
    end
end

def write_top_up_data_to_file(top_up_data)
    def _format_email_list(email_list)
        email_list.map do |data|
            user = data['user']
            [
                "#{user['last_name']}, #{user['first_name']}, #{user['email']}",
                "  Previous token balance: #{data['previous_token_balance']}",
                "  New token balance: #{data['new_token_balance']}"
            ]
        end
        .flatten
    end

    File.open(OUTPUT_FILENAME, 'w') do |file|
        top_up_data.each do |data|
            company = data['company']
    
            file.puts "Company ID: #{company['id']}"
            file.puts "Company Name: #{company['name']}"

            file.puts 'Users emailed:'

            _format_email_list(data['users_emailed'])
            .each { |line| file.puts indent_string(line, 1) }

            file.puts 'Users not emailed:'

            _format_email_list(data['users_not_emailed'])
            .each { |line| file.puts indent_string(line, 1) }

            file.puts "Total top ups: #{data['total_top_ups']}"
            file.puts ''
        end
    end

    puts "Wrote top up data to `#{OUTPUT_FILENAME}`"
end

def main
    # retrieve data, e.g., from files, DB

    users = parse_json_file('users.json')
    companies = parse_json_file('companies.json')

    # validation

    unless _valid_users?(users)
        puts "Invalid user data"
        exit 1
    end

    unless _valid_companies?(companies)
        puts "Invalid company data"
        exit 1
    end

    # core logic
    top_up_data = top_up_many(users, companies)

    # format and output to file
    write_top_up_data_to_file(top_up_data)
end

main
