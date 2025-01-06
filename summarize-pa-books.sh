#!/bin/bash
set -a  # automatically export all variables
source .env
set +a  # stop auto-exporting

# Common curl headers
COMMON_HEADERS=(
    -H 'accept: */*'
    -H 'accept-language: en-US,en;q=0.6'
    -H "cookie: __stripe_mid=$STRIPE_MID; __stripe_sid=$STRIPE_SID; firebase-session=$FIREBASE_SESSION"
    -H 'priority: u=1, i'
    -H 'sec-ch-ua: "Brave";v="131", "Chromium";v="131", "Not_A Brand";v="24"'
    -H 'sec-ch-ua-mobile: ?0'
    -H 'sec-ch-ua-platform: "macOS"'
    -H 'sec-fetch-dest: empty'
    -H 'sec-fetch-mode: cors'
    -H 'sec-fetch-site: same-origin'
    -H 'sec-gpc: 1'
    -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
)

# Function to make API calls
make_api_call() {
    local url=$1
    local referer=$2
    
    curl -s "$url" \
        "${COMMON_HEADERS[@]}" \
        -H "referer: $referer" \
        -H "sentry-trace: $(uuidgen)-$(uuidgen)-1"
}

# Output complete HTML document
cat << 'EOF' > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Peterson Academy - Course Books</title>
    <link rel="stylesheet" href="styles.css">
    <link href="https://fonts.googleapis.com/css2?family=Libre+Baskerville:ital,wght@0,400;0,700;1,400&family=Playfair+Display:wght@400;600&display=swap" rel="stylesheet">
</head>
<body>
    <h1>Peterson Academy - Course Books</h1>
EOF

# Get all courses and process them
make_api_call 'https://petersonacademy.com/api/courses/all' 'https://petersonacademy.com/' | \
jq -c '.[]' | while read -r course; do
    slug=$(echo "$course" | jq -r '.slug')
    
    # Get books for the course directly
    books=$(make_api_call "https://petersonacademy.com/api/courses/$slug/books" "https://petersonacademy.com/courses/$slug")

    # Combine course and book information
    echo "$course" | jq --argjson books "$books" '{
        title: .title,
        slug: .slug,
        id: .id,
        description: .description,
        instructors: .instructors,
        books: $books
    }'
done | jq -s '.' | jq -c '.[]' | while read -r course; do
    title=$(echo "$course" | jq -r '.title')
    slug=$(echo "$course" | jq -r '.slug')
    id=$(echo "$course" | jq -r '.id')
    description=$(echo "$course" | jq -r '.description')
    
    {
        echo "    <div class=\"course-section\">"
        # Header section with inline instructor names
        echo "        <div class=\"course-header\">"
        echo "            <h2 class=\"course-title\"><a href=\"https://petersonacademy.com/courses/$slug\">$title</a></h2>"
        # Process instructors inline
        echo "$course" | jq -r '.instructors | map(.name) | join(" with ")' | while read -r instructor_names; do
            if [[ -n "$instructor_names" && "$instructor_names" != "null" ]]; then
                echo "            <div class=\"course-info\">with $instructor_names</div>"
            fi
        done
        echo "        </div>"
        
        # Image and content
        echo "        <a href=\"https://petersonacademy.com/courses/$slug\" class=\"course-image-link\">"
        echo "            <img src=\"https://ik.imagekit.io/0qkyxdfkk/prod/courses%2F$id%2Fthumb\" alt=\"$title\" class=\"course-image\">"
        echo "        </a>"
        echo "        <div class=\"course-content\">"
        echo "            <h3 class=\"section-heading\">Description</h3>"
        echo "            <div class=\"course-description\">$description</div>"

        # Books section
        books=$(echo "$course" | jq '.books')
        if [[ $(echo "$books" | jq length) -gt 0 ]]; then
            echo "            <div class=\"books-section\">"
            echo "                <h3>Recommended Books</h3>"
            echo "                <div class=\"book-grid\">"
            echo "$books" | jq -r '.[] | "                    <a href=\"\(.url)\" class=\"book-link\">\n                        <img src=\"https://ik.imagekit.io/0qkyxdfkk/prod/books%2F\(.id)%2Fthumb\" alt=\"\(.title)\" class=\"book-image\">\n                        <div class=\"book-title\">\(.title)</div>\n                    </a>"'
            echo "                </div>"
            echo "            </div>"
        fi
        echo "        </div>"

        # Instructor bios
        echo "$course" | jq -c '.instructors[]' | while read -r instructor; do
            bio=$(echo "$instructor" | jq -r '.bio')
            echo "        <div class=\"instructor-bio\">"
            echo "            <strong>About the Instructor</strong>"
            echo "            $bio"
            echo "        </div>"
        done
        echo "    </div>"
    } >> index.html
done

# Close HTML document
echo "</body>" >> index.html
echo "</html>" >> index.html
