# OneOnOne

![Build](https://github.com/kochj23/OneOnOne/actions/workflows/build.yml/badge.svg)

**Never lose an action item again.** OneOnOne helps engineering managers run better 1:1s and team meetings with AI-generated summaries, agenda templates, and automatic action item tracking.

![OneOnOne Screenshot](screenshots/app-screenshot.png)

## Screenshots

*Additional screenshots coming soon -- showing the meeting dashboard, AI summary generation, and action item tracker.*

## Download

Download the latest release: [OneOnOne v2.2.0](https://github.com/kochj23/OneOnOne/releases/latest)

Or build from source (see [Building from Source](#building-from-source) below).

## Why OneOnOne?

- **For Engineering Managers** -- Purpose-built for the specific workflow of managing 1:1s and team meetings
- **AI-Powered Summaries** -- Automatically generate meeting summaries from your notes using local AI via MLX (Machine Learning eXtensions) or cloud providers
- **Action Item Tracking** -- Never let a follow-up slip through the cracks
- **Privacy-First** -- All data stored locally. AI runs on your machine with MLX models.
- **Native macOS & iOS** -- Built with SwiftUI, not a web wrapper. Fast, lightweight, and beautiful.
- **iCloud Sync** -- Seamlessly sync meetings, action items, and notes across all your Apple devices

## Platforms

- **macOS** 14.0+ (Apple Silicon: M1/M2/M3/M4) - Full feature set including AI
- **iOS** 17.0+ (iPhone and iPad) - Core features with iCloud sync

## Features

### Meeting Management
- Track all your 1:1 and team meetings in one place
- Support for multiple meeting types: 1:1, Team, Stand-up, Retrospective, Planning, Review, Brainstorm, Interview, Training
- Record meeting notes, agendas, and outcomes
- Automatic action item tracking from meetings
- Decision logging with rationale
- Meeting mood tracking (Productive, Challenging, Neutral, Positive, Tense)
- Recurring meeting support with calendar integration

### People Management
- Maintain profiles for everyone you meet with
- Track meeting frequency preferences (Daily, Weekly, Bi-weekly, Monthly, Quarterly, As Needed)
- View complete meeting history per person
- Custom tags and notes for each person
- Meeting frequency alerts

### Action Items
- Central view of all action items across meetings
- Priority levels (Low, Medium, High, Urgent)
- Due date tracking with overdue alerts
- Assignee management
- Filter by priority, assignee, or completion status

### Goal Tracking
- Set and track goals for yourself and team members
- Goal categories: Development, Performance, Learning, Project, Personal, Team, Career
- Milestone tracking with completion progress
- Link goals to related meetings
- Goal status tracking (Not Started, In Progress, Completed, On Hold, Cancelled)

### OKR System (Objectives & Key Results)
- Create objectives with measurable key results
- Hierarchical/cascading OKRs
- Team and individual OKR tracking
- Quarterly planning support
- Status tracking (On Track, At Risk, Off Track, Achieved, Cancelled)

### Career Development
- Skill tracking with proficiency levels (Beginner, Intermediate, Advanced, Expert)
- Skill categories: Technical, Leadership, Communication, Problem Solving, Collaboration, Domain Knowledge, Project Management
- Target skill level setting and gap analysis
- Skill assessment history

### Feedback System
- Comprehensive feedback collection per person
- Feedback types: Praise, Recognition, Constructive, Achievement, Thanks, Milestone
- Feedback direction tracking (Given/Received)
- Monthly feedback aggregation and trends

### Team Insights
- Team-wide analytics and metrics
- Cross-person patterns and trends
- Relationship health scoring
- Sentiment tracking (1-5 scale)
- Risk factor identification

### Search & Filtering
- Full-text search across meetings, people, and goals
- Advanced filtering capabilities
- Search history

### Data Portability & Sync
- **iCloud Sync** - Automatic synchronization across all your devices via CloudKit
- Export/Import data in JSON format
- Automatic backups
- Local data storage for privacy

### AI-Powered Insights (macOS only)
- **Meeting Summaries**: AI-generated summaries of meeting notes
- **Weekly Recaps**: Automated summaries of your week
- **Conversation Starters**: AI suggestions for upcoming 1:1s based on past discussions
- **Action Item Extraction**: Automatically identify action items from notes
- **Goal Analysis**: AI assessment of goal progress and recommendations

### Calendar Integration (macOS and iOS)
- Sync with system Calendar app
- Create calendar events for meetings
- Recurring meeting support
- Find available meeting slots

### Voice Recording & Transcription (macOS only)
- Voice recording with consent tracking
- Whisper-based transcription with timestamps
- Speaker diarization support

### Widget (macOS and iOS)
- **Home Screen Widget** with Small, Medium, and Large sizes
- View upcoming meetings at a glance
- Track overdue action items count
- See people you need to meet with soon
- Quick access to the app with meeting context
- Automatic sync when app data changes
- Configurable display options

## Platform Feature Comparison

| Feature | macOS | iOS |
|---------|-------|-----|
| Meeting Management | ✅ | ✅ |
| People Management | ✅ | ✅ |
| Action Items | ✅ | ✅ |
| Goals & OKRs | ✅ | ✅ |
| Career Development | ✅ | ✅ |
| Feedback System | ✅ | ✅ |
| Team Insights | ✅ | ✅ |
| iCloud Sync | ✅ | ✅ |
| Calendar Integration | ✅ | ✅ |
| Home Screen Widget | ✅ | ✅ |
| AI Insights | ✅ | ❌ |
| Voice Recording | ✅ | ❌ |
| Transcription | ✅ | ❌ |
| Third-party Integrations | ✅ | ❌ |

## AI Models (macOS)

OneOnOne uses local MLX models for all AI features, ensuring your meeting data never leaves your computer. Supported models include:
- Llama 3.2 3B Instruct (recommended)
- Qwen 2.5
- Mistral
- Phi-3.5

## Requirements

### macOS
- macOS 14.0 or later
- Apple Silicon Mac (M1/M2/M3/M4)
- For AI features: MLX and mlx-lm Python packages

### iOS
- iOS 17.0 or later
- iPhone or iPad
- iCloud account for sync

## Installation

### macOS
Download the DMG (Disk Image) from the releases page and drag OneOnOne to your Applications folder.

### iOS
Install from the App Store or TestFlight (coming soon).

### Setting up AI Features (macOS)

To use AI features, install the required Python packages:

```bash
pip3 install mlx mlx-lm
```

Then download a model:

```bash
pip3 install huggingface-hub
huggingface-cli download mlx-community/Llama-3.2-3B-Instruct-4bit --local-dir ~/.mlx/models/Llama-3.2-3B-Instruct-4bit
```

## iCloud Sync

OneOnOne uses CloudKit to sync your data across all your Apple devices:

1. Sign in to iCloud on all devices
2. Enable iCloud for OneOnOne in Settings
3. Data syncs automatically in the background

**Sync includes:**
- People profiles
- Meetings and notes
- Action items
- Goals and OKRs
- Feedback entries

## Design

OneOnOne features a modern glassmorphic design with:
- Dark navy gradient backgrounds
- Floating animated blobs
- Frosted glass UI elements
- Vibrant accent colors (cyan, purple, pink, orange, green)

The design matches other apps like MLX Code for a consistent experience.

## Privacy

- All your meeting data is stored locally on your device
- iCloud sync is encrypted end-to-end
- AI features (macOS) run entirely on your device using MLX - no data is sent to external servers
- Calendar access is used only to create and sync meeting events

## Building from Source

```bash
# Install XcodeGen
brew install xcodegen

# Generate Xcode project
cd /path/to/OneOnOne
xcodegen generate

# Build macOS
xcodebuild -scheme OneOnOne -configuration Release

# Build iOS
xcodebuild -scheme OneOnOne-iOS -configuration Release -destination 'generic/platform=iOS'
```

## Version History

### v2.1.0
- Added WidgetKit widget extension (Small, Medium, Large sizes)
- Widget shows upcoming meetings, overdue action items, and people to meet
- App Group support for widget data sharing
- Automatic widget refresh when app data changes

### v2.0.0
- Added iOS support
- Added iCloud sync via CloudKit
- Cross-platform synchronization
- Improved navigation for mobile devices

### v1.1.0
- Initial macOS release
- Full AI-powered insights
- Calendar integration
- Voice recording and transcription

## License

MIT License

Copyright (c) 2026 Jordan Koch

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Author

Jordan Koch

---

## More Apps by Jordan Koch

| App | Description |
|-----|-------------|
| [JiraSummary](https://github.com/kochj23/JiraSummary) | AI-powered Jira dashboard with sprint analytics |
| [MailSummary](https://github.com/kochj23/MailSummary) | AI-powered email categorization and summarization |
| [ExcelExplorer](https://github.com/kochj23/ExcelExplorer) | Native macOS Excel/CSV file viewer |
| [TopGUI](https://github.com/kochj23/TopGUI) | macOS system monitor with real-time metrics |
| [MLXCode](https://github.com/kochj23/MLXCode) | Local AI coding assistant for Apple Silicon |

> **[View all projects](https://github.com/kochj23?tab=repositories)**

---

> **Disclaimer:** This is a personal project created on my own time. It is not affiliated with, endorsed by, or representative of my employer.
