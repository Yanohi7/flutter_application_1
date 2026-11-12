# UI decisions



User decisions take precedence over the original laboratory document



## Confirmed



- Use Entry and Entries throughout the app instead of Note and Notes

- Keep the New menu with separate entry and category forms instead of a shared tabbed editor

- Keep the category creation parent empty by default and the existing explicit parent picker without adding Suggested

- Category navigation may contain any number of rows

- When there are more than two rows, allow collapsing to the first two and expanding again without changing the selected category

- Category rows support mouse and touch dragging without a visible scrollbar or custom vertical wheel conversion

- Open an entry in a separate reading page and open the editor only through an edit action

- Keep the user-written onboarding and help fix completion when requested

- Show only directly assigned entries when a category is selected and label its own entries chip Direct entries

- After creating an entry, select its saved category and clear search and favorite filters

- After creating a category, select that category instead of its parent

- Follow the five visual references in the second DOCX for the presentation redesign

- Use a cool gray canvas, white cards, graphite selection, blue category paths, yellow favorites and red pins

- Place Pin and Favorite as separate controls below the editor content, replacing the earlier app bar decision

- Show category paths only on cards in All Entries, including its Favorites filter, and reveal the full path on tap

- Keep compact Pin and Favorite icons beside the reading page title without a category path

- Keep Edit in the reading page app bar and omit it from that page's action sheet

- Place card actions at the top right and the creation date at the bottom left beside Favorite and Pin

- Long press on category chips or management rows opens Edit / Move and Delete actions, with deletion unavailable for Default

- Profile is a local guest screen; Google sign-in and cloud sync are not connected

- Premium palettes and local activation are implemented at the user's request; real store payment remains separate

- Theme mode, free accent, Premium palette and local Premium access persist through SharedPreferences

- The interface remains in English; remove the nonfunctional language selection

- Remove sample background sheets and all eye-icon notices

- Remove simulated account, sync and purchase states; local Premium activation is free and explicitly separate from store purchases

- Show banner placeholders on home, entry reading and editing, category management and category creation or editing

- Hide form banners while the software keyboard is open and leave Settings, Profile, Premium and onboarding without banners

- Remove the banner demonstration switch; the shared AdBanner disappears on every page when local Premium is active



## Implemented for user review



- The ellipsis button and long press on a card open the same Edit, Move, Duplicate, Delete sheet

- The entry reading page uses the shared actions sheet with Edit hidden because its app bar already provides editing

- The drawer opens Manage Categories, where each category has editing and deletion actions

- The existing category form supports both creation and editing

- Profile displays Guest, local storage status and membership; no sample identity is used

- Premium activates persisted access and unlocks Ocean, Forest, Dusk and Rose palettes, each with light and dark colors

- Empty search results, filters, favorites and categories have contextual explanations and recovery actions



## Remaining differences from the laboratory document



- Manage Categories and the drawer are now included in the presentation redesign

- Entry details displays plain text with separately titled checklists and tables below it

- Duplicate currently copies the supported text entry fields and flags

- Search and filters operate on loaded local entries; appearance settings persist across restarts

- Advertising is a clearly labeled banner placeholder and Remove ads opens Premium

- The Layout preview drawer item has been removed

- Checklists and tables are saved as encoded sections in the entry content and restored by the editor and reading page

- The main entry text remains a normal text field without an inline block editor

- Checklist and table titles are editable, with transparent backgrounds and spacing between groups

- Tables support horizontal dragging without a visible scrollbar and independent display zoom from 25% to 150%

- Table controls append or remove the last row or column, confirming removal of nonempty cells

- Old attachment previews and heading, bullet list and divider tools have been removed

- Real synchronization, advertising delivery, store purchases and authentication remain future work; photo and audio storage are local



## Current collaboration preference



- Show implementation code in chat and apply it directly

- Use English UI text and English code comments beginning with a capital letter and without a trailing period

- Do not run tests unless the user changes this instruction



## Navigation and spacing cleanup — 2026-11-03



- Keep Search, Filter & Sort and Profile in the home toolbar

- Keep Manage categories at the top of the drawer and Settings at its bottom, without a drawer title

- Open Premium through Profile or contextual locked-theme and remove-ads actions

- Keep one Save action at the bottom of entry and category forms

- Use shared icon and button dimensions, compact section spacing and top-aligned entry attachments

- Do not reset onboarding completion automatically on application startup



## Attachment editing and compact tables — 2026-11-04



- Show creation and edit dates above the entry heading

- Keep user checklist and table titles but remove generic Checklists and Tables section labels

- Keep Images and Audio labels, with shared photo Grid / Full selection saved across sessions

- Show optional image captions beneath photos and in the enlarged viewer

- Keep original filenames and paths unchanged while saving user labels in media_attachments.display_name

- Allow multiple draft audio files and recordings with inline rename and remove buttons

- Confirm image and audio removal and apply it only when the entry is saved

- Keep entry deletion confirmation and mark destructive actions in the error color

- Replace four table edge buttons with compact Rows and Columns steppers and remove the decorative table icon



## Documents, backgrounds and private information - 2026-11-04

- Accept PDF, TXT, Markdown, RTF, DOC/DOCX, ODT, CSV, XLS/XLSX and ZIP attachments up to 10 MB per file
- Copy files into app-owned storage on Save and open them through the operating system's associated viewer
- Confirm attachment removal and commit removal with the entry, keeping the original source file untouched
- Premium supports a custom background copied into app storage, resized to 2048 pixels and softened with a theme-aware fade
- Keep the interface in English and do not add translations
- Add one encrypted private-text field per entry without putting it in cards, ordinary content or search
- Use a separate private password for all private fields; never use the device PIN, pattern or password
- Optionally enable strong biometrics on Android 9+ using an authentication-bound Keystore copy with a fresh prompt on every access
- If biometric access is unavailable, use the separate private password; Windows uses this password only
- Re-enroll biometrics through password access if enrollment changes invalidate the biometric key
- Encrypt private text with AES-256-GCM and protect the random master key with PBKDF2-HMAC-SHA256 password derivation
- Lock private text on leaving the app or after 60 seconds without editing; block Android screenshots on the private screen
- Save only ciphertext in SQLite schema version 4 and keep the existing entries when migrating
- Native security and external viewer behavior still need device verification before release
- Windows uses the upstream DPAPI Dart implementation from a local package override; the unused ATL-based legacy migration plugin is excluded and backward compatibility is disabled


## Lists, alignment and private access choices - 2026-11-04

- Private passwords require at least six characters
- First-time Android users may choose a password or strong biometrics directly; biometric-only users can add a backup password after unlocking
- Do not allow removing the only configured unlock method or generating a replacement key for existing private data
- Tables, checklists and plain lists share transparent section styling and saved title alignment
- Table alignment applies within the visible width and expands to the right once the table exceeds it; the title never scrolls horizontally
- Plain lists support bullets, dashes, squares, numbers, lowercase and uppercase letters, Roman numerals and no markers
- Retain existing saved checklist and table content and use left alignment for older entries


## Independent appearance layers - 2026-11-04

- Place file, audio and photo indicators beside the card creation date, with pin and favorite actions remaining on the right
- Separate coordinated interface palettes from solid or illustrated theme backgrounds; selecting a photo does not reset either
- Provide free Slate, Sage and Linen interface palettes and free solid backgrounds, plus Premium gradient, bubble and geometric backgrounds
- Apply interface opacity to cards, navigation and input surfaces while keeping dialogs opaque
- Confirm imported photos in a preview of the actual HomePage at the current viewport aspect ratio, with normalized horizontal and vertical framing, zoom and separate photo and interface opacity controls
- Commit photo settings atomically on Apply and remove unused imported copies on Cancel
- Offer recommended pixel dimensions without restricting aspect ratio; keep existing document limits and resize wallpapers above 4096 pixels
- Preserve the normalized crop across restarts and adapt it when the viewport aspect ratio changes
