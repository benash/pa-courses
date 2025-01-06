#!/bin/bash

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

# Output CSS and header
cat << 'EOF'
<style>
.course-section {
    margin-bottom: 40px;
    clear: both;
}

.course-header {
    width: 100%;
    margin-bottom: 1em;
}

.course-title {
    font-size: 2em;
    margin: 0 0 0.5em 0;
}

.course-title a {
    color: #333;
    text-decoration: none;
}

.course-info {
    color: #666;
    font-style: italic;
    margin-bottom: 1em;
}

.course-image {
    float: left;
    width: 300px;
    height: auto;
    margin-right: 20px;
    margin-bottom: 20px;
}

.course-content {
    overflow: hidden;
}

.course-description {
    line-height: 1.6;
    margin-bottom: 20px;
}

.books-section {
    overflow: hidden;
    margin-bottom: 20px;
}

.book-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 1em;
}

.book-link {
    display: block;
    text-align: center;
}

.book-image {
    height: 150px;
    width: auto;
    object-fit: contain;
    margin-bottom: 0.5em;
}

.book-title {
    font-size: 0.9em;
    color: #333;
    text-decoration: none;
}

.instructor-bio {
    border-left: 3px solid #ddd;
    padding-left: 1em;
    margin: 1em 0;
}

@media (max-width: 768px) {
    .course-image {
        float: none;
        width: 100%;
        margin-right: 0;
    }
}
</style>
# Course Summaries and Recommended Books

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
    
    echo "<div class=\"course-section\">"
    # Header section - full width
    echo "  <div class=\"course-header\">"
    echo "    <h2 class=\"course-title\"><a href=\"https://petersonacademy.com/courses/$slug\">$title</a></h2>"
    # Process instructors
    echo "$course" | jq -r '.instructors | map(.name) | join(" with ")' | while read -r instructor_names; do
        if [[ -n "$instructor_names" && "$instructor_names" != "null" ]]; then
            echo "    <div class=\"course-info\">with $instructor_names</div>"
        fi
    done
    echo "  </div>"
    
    # Image and content
    echo "  <img src=\"https://ik.imagekit.io/0qkyxdfkk/prod/courses%2F$id%2Fthumb\" alt=\"$title\" class=\"course-image\">"
    echo "  <div class=\"course-content\">"
    echo "    <div class=\"course-description\">$description</div>"

    # Books section
    books=$(echo "$course" | jq '.books')
    if [[ $(echo "$books" | jq length) -gt 0 ]]; then
        echo "    <div class=\"books-section\">"
        echo "      <h3>Recommended Books</h3>"
        echo "      <div class=\"book-grid\">"
        echo "$books" | jq -r '.[] | "        <a href=\"\(.url)\" class=\"book-link\">\n          <img src=\"https://ik.imagekit.io/0qkyxdfkk/prod/books%2F\(.id)%2Fthumb\" alt=\"\(.title)\" class=\"book-image\">\n          <div class=\"book-title\">\(.title)</div>\n        </a>"'
        echo "      </div>"
        echo "    </div>"
    fi

    # Instructor bios
    echo "$course" | jq -c '.instructors[]' | while read -r instructor; do
        bio=$(echo "$instructor" | jq -r '.bio')
        echo "    <blockquote class=\"instructor-bio\">"
        echo "      <strong>About the Instructor</strong><br>"
        echo "      $bio"
        echo "    </blockquote>"
    done
    echo "  </div>"
    echo "</div>"
    echo
done
