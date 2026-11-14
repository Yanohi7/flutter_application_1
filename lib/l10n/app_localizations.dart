import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('pl'),
    Locale('uk'),
  ];

  /// No description provided for @newEntry.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get newEntry;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @deviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get deviceLanguage;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appBrightnessTheme.
  ///
  /// In en, this message translates to:
  /// **'App Brightness Theme'**
  String get appBrightnessTheme;

  /// No description provided for @appColorTheme.
  ///
  /// In en, this message translates to:
  /// **'App Color Theme'**
  String get appColorTheme;

  /// No description provided for @chooseAModeOrFollowYourDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose a mode, or follow your device.'**
  String get chooseAModeOrFollowYourDevice;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @yourWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Your workspace'**
  String get yourWorkspace;

  /// No description provided for @allEntries.
  ///
  /// In en, this message translates to:
  /// **'All Entries'**
  String get allEntries;

  /// No description provided for @showAllEntries.
  ///
  /// In en, this message translates to:
  /// **'Show all entries'**
  String get showAllEntries;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategories;

  /// No description provided for @manageCategoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get manageCategoriesLabel;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @addEntry.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get addEntry;

  /// No description provided for @entry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get entry;

  /// No description provided for @entryTitle.
  ///
  /// In en, this message translates to:
  /// **'Entry title'**
  String get entryTitle;

  /// No description provided for @entryText.
  ///
  /// In en, this message translates to:
  /// **'Entry text…'**
  String get entryText;

  /// No description provided for @entryActions.
  ///
  /// In en, this message translates to:
  /// **'Entry actions'**
  String get entryActions;

  /// No description provided for @entrySaved.
  ///
  /// In en, this message translates to:
  /// **'Entry saved'**
  String get entrySaved;

  /// No description provided for @entryDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Entry duplicated'**
  String get entryDuplicated;

  /// No description provided for @entryMoved.
  ///
  /// In en, this message translates to:
  /// **'Entry moved'**
  String get entryMoved;

  /// No description provided for @noTextYet.
  ///
  /// In en, this message translates to:
  /// **'No text yet'**
  String get noTextYet;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @continueWriting.
  ///
  /// In en, this message translates to:
  /// **'Continue writing…'**
  String get continueWriting;

  /// No description provided for @enterAnEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter an entry title'**
  String get enterAnEntryTitle;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryPath.
  ///
  /// In en, this message translates to:
  /// **'Category path'**
  String get categoryPath;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @categoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Category created'**
  String get categoryCreated;

  /// No description provided for @createNewCategory.
  ///
  /// In en, this message translates to:
  /// **'Create New Category'**
  String get createNewCategory;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get chooseCategory;

  /// No description provided for @selectACategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get selectACategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @saveCategory.
  ///
  /// In en, this message translates to:
  /// **'Save category'**
  String get saveCategory;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get deleteCategory;

  /// No description provided for @parentCategory.
  ///
  /// In en, this message translates to:
  /// **'Parent category'**
  String get parentCategory;

  /// No description provided for @noneTopLevel.
  ///
  /// In en, this message translates to:
  /// **'None (top level)'**
  String get noneTopLevel;

  /// No description provided for @defaultCategory.
  ///
  /// In en, this message translates to:
  /// **'Default category'**
  String get defaultCategory;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @directEntries.
  ///
  /// In en, this message translates to:
  /// **'Direct entries'**
  String get directEntries;

  /// No description provided for @addSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Add subcategory'**
  String get addSubcategory;

  /// No description provided for @noCategoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get noCategoriesFound;

  /// No description provided for @searchCategories.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get searchCategories;

  /// No description provided for @clearCategorySearch.
  ///
  /// In en, this message translates to:
  /// **'Clear category search'**
  String get clearCategorySearch;

  /// No description provided for @enterTheCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Enter the category name.'**
  String get enterTheCategoryName;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get deleting;

  /// No description provided for @deleteTheEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete the entry?'**
  String get deleteTheEntry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @continueOffline.
  ///
  /// In en, this message translates to:
  /// **'Continue offline'**
  String get continueOffline;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @pleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get pleaseTryAgain;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get pleaseWait;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editMove.
  ///
  /// In en, this message translates to:
  /// **'Edit / Move'**
  String get editMove;

  /// No description provided for @renameMove.
  ///
  /// In en, this message translates to:
  /// **'Rename / Move'**
  String get renameMove;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @moveEntry.
  ///
  /// In en, this message translates to:
  /// **'Move entry'**
  String get moveEntry;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @discardUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get discardUnsavedChanges;

  /// No description provided for @ifYouLeaveNowYourChangesWillNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'If you leave now, your changes will not be saved.'**
  String get ifYouLeaveNowYourChangesWillNotBeSaved;

  /// No description provided for @readingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get readingMode;

  /// No description provided for @exitReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Exit reading mode'**
  String get exitReadingMode;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @favorited.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get favorited;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchEntries.
  ///
  /// In en, this message translates to:
  /// **'Search entries'**
  String get searchEntries;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @globalSearch.
  ///
  /// In en, this message translates to:
  /// **'Global Search'**
  String get globalSearch;

  /// No description provided for @inCurrentCategory.
  ///
  /// In en, this message translates to:
  /// **'In Current Category'**
  String get inCurrentCategory;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No search results'**
  String get noSearchResults;

  /// No description provided for @filterSort.
  ///
  /// In en, this message translates to:
  /// **'Filter & Sort'**
  String get filterSort;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @dateCreated.
  ///
  /// In en, this message translates to:
  /// **'Date created'**
  String get dateCreated;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @oldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get oldest;

  /// No description provided for @lastEdited.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get lastEdited;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @allTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get allTypes;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFilters;

  /// No description provided for @clearSearchAndFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear search and filters'**
  String get clearSearchAndFilters;

  /// No description provided for @noteSize.
  ///
  /// In en, this message translates to:
  /// **'Note size'**
  String get noteSize;

  /// No description provided for @compact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get compact;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get grid;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get full;

  /// No description provided for @imageActions.
  ///
  /// In en, this message translates to:
  /// **'Image actions'**
  String get imageActions;

  /// No description provided for @closeImage.
  ///
  /// In en, this message translates to:
  /// **'Close image'**
  String get closeImage;

  /// No description provided for @previousImage.
  ///
  /// In en, this message translates to:
  /// **'Previous image'**
  String get previousImage;

  /// No description provided for @nextImage.
  ///
  /// In en, this message translates to:
  /// **'Next image'**
  String get nextImage;

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get removeImage;

  /// No description provided for @removeImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove image?'**
  String get removeImageLabel;

  /// No description provided for @addCaption.
  ///
  /// In en, this message translates to:
  /// **'Add caption'**
  String get addCaption;

  /// No description provided for @editCaption.
  ///
  /// In en, this message translates to:
  /// **'Edit caption'**
  String get editCaption;

  /// No description provided for @imageCaption.
  ///
  /// In en, this message translates to:
  /// **'Image caption'**
  String get imageCaption;

  /// No description provided for @optionalCaption.
  ///
  /// In en, this message translates to:
  /// **'Optional caption'**
  String get optionalCaption;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @audioFiles.
  ///
  /// In en, this message translates to:
  /// **'Audio files'**
  String get audioFiles;

  /// No description provided for @addAudio.
  ///
  /// In en, this message translates to:
  /// **'Add audio'**
  String get addAudio;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recording;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @tapToListen.
  ///
  /// In en, this message translates to:
  /// **'Tap to listen'**
  String get tapToListen;

  /// No description provided for @playAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get playAudio;

  /// No description provided for @pauseAudio.
  ///
  /// In en, this message translates to:
  /// **'Pause audio'**
  String get pauseAudio;

  /// No description provided for @closePlayer.
  ///
  /// In en, this message translates to:
  /// **'Close player'**
  String get closePlayer;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @audioName.
  ///
  /// In en, this message translates to:
  /// **'Audio name'**
  String get audioName;

  /// No description provided for @enterAnAudioName.
  ///
  /// In en, this message translates to:
  /// **'Enter an audio name'**
  String get enterAnAudioName;

  /// No description provided for @renameAudio.
  ///
  /// In en, this message translates to:
  /// **'Rename audio'**
  String get renameAudio;

  /// No description provided for @removeAudio.
  ///
  /// In en, this message translates to:
  /// **'Remove audio'**
  String get removeAudio;

  /// No description provided for @removeAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove audio?'**
  String get removeAudioLabel;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @addFiles.
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get addFiles;

  /// No description provided for @removeFile.
  ///
  /// In en, this message translates to:
  /// **'Remove file'**
  String get removeFile;

  /// No description provided for @removeFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove file?'**
  String get removeFileLabel;

  /// No description provided for @openWithAnotherApp.
  ///
  /// In en, this message translates to:
  /// **'Open with another app'**
  String get openWithAnotherApp;

  /// No description provided for @documentsArchivesAndVideo.
  ///
  /// In en, this message translates to:
  /// **'Documents, archives and video'**
  String get documentsArchivesAndVideo;

  /// No description provided for @documentsZipAndVideoUpTo10MbEach.
  ///
  /// In en, this message translates to:
  /// **'Documents, ZIP and video · Up to 10 MB each'**
  String get documentsZipAndVideoUpTo10MbEach;

  /// No description provided for @addChecklist.
  ///
  /// In en, this message translates to:
  /// **'Add checklist'**
  String get addChecklist;

  /// No description provided for @checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// No description provided for @checklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklist title'**
  String get checklistTitle;

  /// No description provided for @checked.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get checked;

  /// No description provided for @unchecked.
  ///
  /// In en, this message translates to:
  /// **'Unchecked'**
  String get unchecked;

  /// No description provided for @addList.
  ///
  /// In en, this message translates to:
  /// **'Add list'**
  String get addList;

  /// No description provided for @listTitle.
  ///
  /// In en, this message translates to:
  /// **'List title'**
  String get listTitle;

  /// No description provided for @listItem.
  ///
  /// In en, this message translates to:
  /// **'List item'**
  String get listItem;

  /// No description provided for @listMarkers.
  ///
  /// In en, this message translates to:
  /// **'List markers'**
  String get listMarkers;

  /// No description provided for @noMarkers.
  ///
  /// In en, this message translates to:
  /// **'No markers'**
  String get noMarkers;

  /// No description provided for @addTable.
  ///
  /// In en, this message translates to:
  /// **'Add table'**
  String get addTable;

  /// No description provided for @tableTitle.
  ///
  /// In en, this message translates to:
  /// **'Table title'**
  String get tableTitle;

  /// No description provided for @rows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get rows;

  /// No description provided for @columns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columns;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get removeItem;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @collapseToTwoRows.
  ///
  /// In en, this message translates to:
  /// **'Collapse to two rows'**
  String get collapseToTwoRows;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// No description provided for @addProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Add profile photo'**
  String get addProfilePhoto;

  /// No description provided for @viewProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'View profile photo'**
  String get viewProfilePhoto;

  /// No description provided for @adjustProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Adjust profile photo'**
  String get adjustProfilePhoto;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @removeProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove profile photo?'**
  String get removeProfilePhoto;

  /// No description provided for @googleAccount.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get googleAccount;

  /// No description provided for @googleAccountOptions.
  ///
  /// In en, this message translates to:
  /// **'Google account options'**
  String get googleAccountOptions;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @autoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync'**
  String get autoSync;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get neverSynced;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @keepBoth.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get keepBoth;

  /// No description provided for @differentVersionsFound.
  ///
  /// In en, this message translates to:
  /// **'Different versions found'**
  String get differentVersionsFound;

  /// No description provided for @keepBothVersions.
  ///
  /// In en, this message translates to:
  /// **'Keep both versions?'**
  String get keepBothVersions;

  /// No description provided for @freePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get freePlan;

  /// No description provided for @getPremium.
  ///
  /// In en, this message translates to:
  /// **'Get Premium'**
  String get getPremium;

  /// No description provided for @explorePremium.
  ///
  /// In en, this message translates to:
  /// **'Explore Premium'**
  String get explorePremium;

  /// No description provided for @unlimitedAttachments.
  ///
  /// In en, this message translates to:
  /// **'Unlimited attachments'**
  String get unlimitedAttachments;

  /// No description provided for @anAdFreeWorkspace.
  ///
  /// In en, this message translates to:
  /// **'An ad-free workspace'**
  String get anAdFreeWorkspace;

  /// No description provided for @allPremiumColorThemes.
  ///
  /// In en, this message translates to:
  /// **'All Premium color themes'**
  String get allPremiumColorThemes;

  /// No description provided for @yourOwnPhotoBackgrounds.
  ///
  /// In en, this message translates to:
  /// **'Your own photo backgrounds'**
  String get yourOwnPhotoBackgrounds;

  /// No description provided for @photoBackground.
  ///
  /// In en, this message translates to:
  /// **'Photo background'**
  String get photoBackground;

  /// No description provided for @backgroundPhotos.
  ///
  /// In en, this message translates to:
  /// **'Background photos'**
  String get backgroundPhotos;

  /// No description provided for @addBackgroundPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add background photo'**
  String get addBackgroundPhoto;

  /// No description provided for @adjustPhoto.
  ///
  /// In en, this message translates to:
  /// **'Adjust photo'**
  String get adjustPhoto;

  /// No description provided for @previewBackground.
  ///
  /// In en, this message translates to:
  /// **'Preview background'**
  String get previewBackground;

  /// No description provided for @applyBackground.
  ///
  /// In en, this message translates to:
  /// **'Apply background'**
  String get applyBackground;

  /// No description provided for @applyOpacity.
  ///
  /// In en, this message translates to:
  /// **'Apply opacity'**
  String get applyOpacity;

  /// No description provided for @interfaceOpacity.
  ///
  /// In en, this message translates to:
  /// **'Interface opacity'**
  String get interfaceOpacity;

  /// No description provided for @removeBackgroundPhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove background photo?'**
  String get removeBackgroundPhoto;

  /// No description provided for @removePhotoUseThemeBackground.
  ///
  /// In en, this message translates to:
  /// **'Remove photo · use theme background'**
  String get removePhotoUseThemeBackground;

  /// No description provided for @resetFraming.
  ///
  /// In en, this message translates to:
  /// **'Reset framing'**
  String get resetFraming;

  /// No description provided for @resetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get resetZoom;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @usePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use photo'**
  String get usePhoto;

  /// No description provided for @privateInformation.
  ///
  /// In en, this message translates to:
  /// **'Private information'**
  String get privateInformation;

  /// No description provided for @privateInformationLocked.
  ///
  /// In en, this message translates to:
  /// **'Private information · Locked'**
  String get privateInformationLocked;

  /// No description provided for @passwordsAndSensitiveText.
  ///
  /// In en, this message translates to:
  /// **'Passwords and sensitive text'**
  String get passwordsAndSensitiveText;

  /// No description provided for @privatePassword.
  ///
  /// In en, this message translates to:
  /// **'Private password'**
  String get privatePassword;

  /// No description provided for @newPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'New private password'**
  String get newPrivatePassword;

  /// No description provided for @repeatPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat private password'**
  String get repeatPrivatePassword;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create password'**
  String get createPassword;

  /// No description provided for @changePrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Change private password'**
  String get changePrivatePassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Reset private password'**
  String get resetPrivatePassword;

  /// No description provided for @setANewPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Set a new private password'**
  String get setANewPrivatePassword;

  /// No description provided for @addABackupPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Add a backup private password'**
  String get addABackupPrivatePassword;

  /// No description provided for @savePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get savePassword;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @lockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNow;

  /// No description provided for @unlockWithBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get unlockWithBiometrics;

  /// No description provided for @useBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get useBiometrics;

  /// No description provided for @enableBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Enable biometrics'**
  String get enableBiometrics;

  /// No description provided for @setUpBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Set up biometrics'**
  String get setUpBiometrics;

  /// No description provided for @setUpBiometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Set up biometric unlock'**
  String get setUpBiometricUnlock;

  /// No description provided for @useScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Use screen lock'**
  String get useScreenLock;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @usePrivateInformation.
  ///
  /// In en, this message translates to:
  /// **'Use private information'**
  String get usePrivateInformation;

  /// No description provided for @discardPrivateChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard private changes?'**
  String get discardPrivateChanges;

  /// No description provided for @adPrivacyChoices.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get adPrivacyChoices;

  /// No description provided for @watchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch ad'**
  String get watchAd;

  /// No description provided for @loadingAd.
  ///
  /// In en, this message translates to:
  /// **'Loading ad…'**
  String get loadingAd;

  /// No description provided for @addAnotherAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add another attachment'**
  String get addAnotherAttachment;

  /// No description provided for @startPremiumPreview.
  ///
  /// In en, this message translates to:
  /// **'Start Premium preview'**
  String get startPremiumPreview;

  /// No description provided for @endPremiumPreview.
  ///
  /// In en, this message translates to:
  /// **'End Premium preview'**
  String get endPremiumPreview;

  /// No description provided for @captureYourIdeas.
  ///
  /// In en, this message translates to:
  /// **'Capture your ideas'**
  String get captureYourIdeas;

  /// No description provided for @giveEverythingAPlace.
  ///
  /// In en, this message translates to:
  /// **'Give everything a place'**
  String get giveEverythingAPlace;

  /// No description provided for @takeYourEntriesWithYou.
  ///
  /// In en, this message translates to:
  /// **'Take your entries with you'**
  String get takeYourEntriesWithYou;

  /// No description provided for @startUsingEntries.
  ///
  /// In en, this message translates to:
  /// **'Start using Entries'**
  String get startUsingEntries;

  /// No description provided for @startWithYourFirstEntry.
  ///
  /// In en, this message translates to:
  /// **'Start with your first entry'**
  String get startWithYourFirstEntry;

  /// No description provided for @captureAnIdeaAndKeepItOrganized.
  ///
  /// In en, this message translates to:
  /// **'Capture an idea and keep it organized.'**
  String get captureAnIdeaAndKeepItOrganized;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @noMatchingEntries.
  ///
  /// In en, this message translates to:
  /// **'No matching entries'**
  String get noMatchingEntries;

  /// No description provided for @thisCategoryIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'This category is empty'**
  String get thisCategoryIsEmpty;

  /// No description provided for @tapTheStarOnAnEntryToKeepItHere.
  ///
  /// In en, this message translates to:
  /// **'Tap the star on an entry to keep it here.'**
  String get tapTheStarOnAnEntryToKeepItHere;

  /// No description provided for @entriesSavedOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Entries saved on this device'**
  String get entriesSavedOnThisDevice;

  /// No description provided for @couldNotOpenThisImage.
  ///
  /// In en, this message translates to:
  /// **'Could not open this image.'**
  String get couldNotOpenThisImage;

  /// No description provided for @couldNotOpenEntries.
  ///
  /// In en, this message translates to:
  /// **'Could not open entries'**
  String get couldNotOpenEntries;

  /// No description provided for @couldNotSaveYourPreferencesPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not save your preferences. Please try again.'**
  String get couldNotSaveYourPreferencesPleaseTryAgain;

  /// No description provided for @startWithAThoughtAddAChecklistAPhotoOrAVoiceRecordingWhenYouNeedIt.
  ///
  /// In en, this message translates to:
  /// **'Start with a thought. Add a checklist, a photo or a voice recording when you need it.'**
  String get startWithAThoughtAddAChecklistAPhotoOrAVoiceRecordingWhenYouNeedIt;

  /// No description provided for @groupEntriesInCategoriesPinWhatMattersAndFindItAgainWithSearch.
  ///
  /// In en, this message translates to:
  /// **'Group entries in categories, pin what matters and find it again with search.'**
  String get groupEntriesInCategoriesPinWhatMattersAndFindItAgainWithSearch;

  /// No description provided for @signInWithGoogleToSyncEntriesCategoriesAndAttachmentsAcrossYourDevicesYouCanAlwaysWorkOffline.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google to sync entries, categories and attachments across your devices. You can always work offline.'**
  String
  get signInWithGoogleToSyncEntriesCategoriesAndAttachmentsAcrossYourDevicesYouCanAlwaysWorkOffline;

  /// No description provided for @noEntriesMatchYourSearchAndFiltersInThisView.
  ///
  /// In en, this message translates to:
  /// **'No entries match your search and filters in this view.'**
  String get noEntriesMatchYourSearchAndFiltersInThisView;

  /// No description provided for @tryADifferentTitleOrTextOrSearchInAllCategories.
  ///
  /// In en, this message translates to:
  /// **'Try a different title or text, or search in all categories.'**
  String get tryADifferentTitleOrTextOrSearchInAllCategories;

  /// No description provided for @tryAnotherDateRangeOrContentTypeForThisView.
  ///
  /// In en, this message translates to:
  /// **'Try another date range or content type for this view.'**
  String get tryAnotherDateRangeOrContentTypeForThisView;

  /// No description provided for @entriesAssignedDirectlyToThisCategoryWillAppearHereSubcategoriesHaveTheirOwnEntries.
  ///
  /// In en, this message translates to:
  /// **'Entries assigned directly to this category will appear here. Subcategories have their own entries.'**
  String
  get entriesAssignedDirectlyToThisCategoryWillAppearHereSubcategoriesHaveTheirOwnEntries;

  /// No description provided for @keepTheFocusOnYourNotes.
  ///
  /// In en, this message translates to:
  /// **'Keep the focus on your notes'**
  String get keepTheFocusOnYourNotes;

  /// No description provided for @makeSpaceForYourIdeas.
  ///
  /// In en, this message translates to:
  /// **'Make space for your ideas'**
  String get makeSpaceForYourIdeas;

  /// No description provided for @beautifulColorThemesAFocusedWorkspaceMoreRoomForWhatMatters.
  ///
  /// In en, this message translates to:
  /// **'Beautiful color themes. A focused workspace. More room for what matters.'**
  String get beautifulColorThemesAFocusedWorkspaceMoreRoomForWhatMatters;

  /// No description provided for @coordinatedColorsInLightDarkAndSystemModes.
  ///
  /// In en, this message translates to:
  /// **'Coordinated colors in Light, Dark and System modes'**
  String get coordinatedColorsInLightDarkAndSystemModes;

  /// No description provided for @customFramingZoomAndInterfaceTransparency.
  ///
  /// In en, this message translates to:
  /// **'Custom framing, zoom and interface transparency'**
  String get customFramingZoomAndInterfaceTransparency;

  /// No description provided for @addAsManyFilesAsYouLikeWithoutWatchingAds.
  ///
  /// In en, this message translates to:
  /// **'Add as many files as you like without watching ads.'**
  String get addAsManyFilesAsYouLikeWithoutWatchingAds;

  /// No description provided for @unlockPhotoBackgroundsFor24Hours.
  ///
  /// In en, this message translates to:
  /// **'Unlock photo backgrounds for 24 hours.'**
  String get unlockPhotoBackgroundsFor24Hours;

  /// No description provided for @purchasesAreNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'Purchases are not available yet.'**
  String get purchasesAreNotAvailableYet;

  /// No description provided for @freePreviewNoPaymentRequired.
  ///
  /// In en, this message translates to:
  /// **'Free preview. No payment required.'**
  String get freePreviewNoPaymentRequired;

  /// No description provided for @noAdsAllColorThemesUnlocked.
  ///
  /// In en, this message translates to:
  /// **'No ads · All color themes unlocked'**
  String get noAdsAllColorThemesUnlocked;

  /// No description provided for @dragToRepositionPinchOrUseTheZoomSlider.
  ///
  /// In en, this message translates to:
  /// **'Drag to reposition. Pinch or use the zoom slider.'**
  String get dragToRepositionPinchOrUseTheZoomSlider;

  /// No description provided for @dragThePhotoToRepositionItOrPinchToZoom.
  ///
  /// In en, this message translates to:
  /// **'Drag the photo to reposition it or pinch to zoom.'**
  String get dragThePhotoToRepositionItOrPinchToZoom;

  /// No description provided for @makeItYoursWithAPhotoPreviewTheCropAndAdjustReadabilityBeforeApplying.
  ///
  /// In en, this message translates to:
  /// **'Make it yours with a photo. Preview the crop and adjust readability before applying.'**
  String
  get makeItYoursWithAPhotoPreviewTheCropAndAdjustReadabilityBeforeApplying;

  /// No description provided for @previewTheChangeOnYourNotesBeforeApplyingIt.
  ///
  /// In en, this message translates to:
  /// **'Preview the change on your notes before applying it.'**
  String get previewTheChangeOnYourNotesBeforeApplyingIt;

  /// No description provided for @yourCurrentColorThemeWillBecomeTheBackgroundAgain.
  ///
  /// In en, this message translates to:
  /// **'Your current color theme will become the background again.'**
  String get yourCurrentColorThemeWillBecomeTheBackgroundAgain;

  /// No description provided for @yourProfileWillShowTheDefaultAvatar.
  ///
  /// In en, this message translates to:
  /// **'Your profile will show the default avatar.'**
  String get yourProfileWillShowTheDefaultAvatar;

  /// No description provided for @thisActionCannotBeUndoneInTheApp.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone in the app.'**
  String get thisActionCannotBeUndoneInTheApp;

  /// No description provided for @deletingThisCategoryWillAlsoDelete.
  ///
  /// In en, this message translates to:
  /// **'Deleting this category will also delete:'**
  String get deletingThisCategoryWillAlsoDelete;

  /// No description provided for @includesAllNestedLevels.
  ///
  /// In en, this message translates to:
  /// **'Includes all nested levels'**
  String get includesAllNestedLevels;

  /// No description provided for @includesTheirAttachments.
  ///
  /// In en, this message translates to:
  /// **'Includes their attachments'**
  String get includesTheirAttachments;

  /// No description provided for @yourCategoryChangesWillNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'Your category changes will not be saved.'**
  String get yourCategoryChangesWillNotBeSaved;

  /// No description provided for @onlyThisPrivateFieldIsEncryptedTheTitleNormalTextAndAttachmentsRemainVisible.
  ///
  /// In en, this message translates to:
  /// **'Only this private field is encrypted. The title, normal text and attachments remain visible.'**
  String
  get onlyThisPrivateFieldIsEncryptedTheTitleNormalTextAndAttachmentsRemainVisible;

  /// No description provided for @locksWhenYouLeaveTheAppOrAfter60SecondsOfInactivity.
  ///
  /// In en, this message translates to:
  /// **'Locks when you leave the app or after 60 seconds of inactivity.'**
  String get locksWhenYouLeaveTheAppOrAfter60SecondsOfInactivity;

  /// No description provided for @saveTheEntryAfterwardsToKeepTheseChanges.
  ///
  /// In en, this message translates to:
  /// **'Save the entry afterwards to keep these changes.'**
  String get saveTheEntryAfterwardsToKeepTheseChanges;

  /// No description provided for @passwordRecoveryDetailsOrOtherPrivateInformation.
  ///
  /// In en, this message translates to:
  /// **'Password, recovery details or other private information'**
  String get passwordRecoveryDetailsOrOtherPrivateInformation;

  /// No description provided for @useAtLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters.'**
  String get useAtLeast6Characters;

  /// No description provided for @useAtLeast6CharactersAndEnterTheSamePasswordTwice.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters and enter the same password twice.'**
  String get useAtLeast6CharactersAndEnterTheSamePasswordTwice;

  /// No description provided for @enterYourPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your private password.'**
  String get enterYourPrivatePassword;

  /// No description provided for @enterYourPrivatePasswordOrUseBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Enter your private password or use biometrics.'**
  String get enterYourPrivatePasswordOrUseBiometrics;

  /// No description provided for @createAPasswordToProtectThisSection.
  ///
  /// In en, this message translates to:
  /// **'Create a password to protect this section.'**
  String get createAPasswordToProtectThisSection;

  /// No description provided for @aScreenLockLetsYouResetThisPasswordOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'A screen lock lets you reset this password on this phone.'**
  String get aScreenLockLetsYouResetThisPasswordOnThisPhone;

  /// No description provided for @useYourPhoneSBiometricsToSetANewPassword.
  ///
  /// In en, this message translates to:
  /// **'Use your phone’s biometrics to set a new password.'**
  String get useYourPhoneSBiometricsToSetANewPassword;

  /// No description provided for @useTheFingerprintOrFaceRecognitionConfiguredOnThisDeviceForEverydayAccess.
  ///
  /// In en, this message translates to:
  /// **'Use the fingerprint or face recognition configured on this device for everyday access.'**
  String
  get useTheFingerprintOrFaceRecognitionConfiguredOnThisDeviceForEverydayAccess;

  /// No description provided for @unlockWithYourFingerprintOrFaceRecognitionOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your fingerprint or face recognition on this device.'**
  String get unlockWithYourFingerprintOrFaceRecognitionOnThisDevice;

  /// No description provided for @unlockWithBiometricsToSetABackupPassword.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics to set a backup password.'**
  String get unlockWithBiometricsToSetABackupPassword;

  /// No description provided for @addAFingerprintOrFaceUnlockInYourPhoneSettingsThenReturnHereAndTapUseBiometricsAgain.
  ///
  /// In en, this message translates to:
  /// **'Add a fingerprint or face unlock in your phone settings. Then return here and tap Use biometrics again.'**
  String
  get addAFingerprintOrFaceUnlockInYourPhoneSettingsThenReturnHereAndTapUseBiometricsAgain;

  /// No description provided for @theseChangesHaveNotBeenAddedToTheEntryYet.
  ///
  /// In en, this message translates to:
  /// **'These changes have not been added to the entry yet.'**
  String get theseChangesHaveNotBeenAddedToTheEntryYet;

  /// No description provided for @theFirstAttachmentIsFreeCompleteOneAdToAddThisAttachment.
  ///
  /// In en, this message translates to:
  /// **'The first attachment is free. Complete one ad to add this attachment.'**
  String get theFirstAttachmentIsFreeCompleteOneAdToAddThisAttachment;

  /// No description provided for @finishTheAdForItToCount.
  ///
  /// In en, this message translates to:
  /// **'Finish the ad for it to count.'**
  String get finishTheAdForItToCount;

  /// No description provided for @finishTheAdToAddThisAttachment.
  ///
  /// In en, this message translates to:
  /// **'Finish the ad to add this attachment.'**
  String get finishTheAdToAddThisAttachment;

  /// No description provided for @anAdIsUnavailableRightNowTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'An ad is unavailable right now. Try again later.'**
  String get anAdIsUnavailableRightNowTryAgainLater;

  /// No description provided for @thisAttachmentWillBeRemovedFromTheEntryWhenYouSave.
  ///
  /// In en, this message translates to:
  /// **'This attachment will be removed from the entry when you save.'**
  String get thisAttachmentWillBeRemovedFromTheEntryWhenYouSave;

  /// No description provided for @someFilesWereSkippedUseSupportedFilesUpTo10MbEach.
  ///
  /// In en, this message translates to:
  /// **'Some files were skipped. Use supported files up to 10 MB each.'**
  String get someFilesWereSkippedUseSupportedFilesUpTo10MbEach;

  /// No description provided for @theDefaultCategoryCannotBeDeleted.
  ///
  /// In en, this message translates to:
  /// **'The default category cannot be deleted'**
  String get theDefaultCategoryCannotBeDeleted;

  /// No description provided for @theDefaultCategoryStaysAtTheTopLevel.
  ///
  /// In en, this message translates to:
  /// **'The default category stays at the top level'**
  String get theDefaultCategoryStaysAtTheTopLevel;

  /// No description provided for @microphonePermissionWasDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was denied.'**
  String get microphonePermissionWasDenied;

  /// No description provided for @audioIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audio is unavailable.'**
  String get audioIsUnavailable;

  /// No description provided for @couldNotPlayThisAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Could not play this audio file.'**
  String get couldNotPlayThisAudioFile;

  /// No description provided for @couldNotOpenThisFileItMayNoLongerBeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open this file. It may no longer be available.'**
  String get couldNotOpenThisFileItMayNoLongerBeAvailable;

  /// No description provided for @googleDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get googleDrive;

  /// No description provided for @entries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get entries;

  /// No description provided for @couldNotSaveThisReward.
  ///
  /// In en, this message translates to:
  /// **'Could not save this reward.'**
  String get couldNotSaveThisReward;

  /// No description provided for @googleSignInWasCanceled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in was canceled.'**
  String get googleSignInWasCanceled;

  /// No description provided for @couldNotConnectGoogle.
  ///
  /// In en, this message translates to:
  /// **'Could not connect your Google account. Try again.'**
  String get couldNotConnectGoogle;

  /// No description provided for @googleTimeout.
  ///
  /// In en, this message translates to:
  /// **'Google took too long to respond. Try again.'**
  String get googleTimeout;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get checkConnection;

  /// No description provided for @couldNotSync.
  ///
  /// In en, this message translates to:
  /// **'Could not sync. Your entries are safe on this device.'**
  String get couldNotSync;

  /// No description provided for @nothingToSync.
  ///
  /// In en, this message translates to:
  /// **'There are no entries to sync yet.'**
  String get nothingToSync;

  /// No description provided for @entriesCurrent.
  ///
  /// In en, this message translates to:
  /// **'Entries are up to date.'**
  String get entriesCurrent;

  /// No description provided for @entriesUploaded.
  ///
  /// In en, this message translates to:
  /// **'Entries uploaded to Google Drive.'**
  String get entriesUploaded;

  /// No description provided for @entriesDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Entries downloaded from Google Drive.'**
  String get entriesDownloaded;

  /// No description provided for @bothVersionsSynced.
  ///
  /// In en, this message translates to:
  /// **'Both sets of entries are now synced. See Google Drive copies for imported entries.'**
  String get bothVersionsSynced;

  /// No description provided for @lastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync · {date}, {time}'**
  String lastSync(String date, String time);

  /// No description provided for @tryThemeFor24Hours.
  ///
  /// In en, this message translates to:
  /// **'Try {theme} for 24 hours.'**
  String tryThemeFor24Hours(String theme);

  /// No description provided for @watchAdNumber.
  ///
  /// In en, this message translates to:
  /// **'Watch ad {number} of 2'**
  String watchAdNumber(int number);

  /// No description provided for @onboardingPage.
  ///
  /// In en, this message translates to:
  /// **'Page {number} of {total}'**
  String onboardingPage(int number, int total);

  /// No description provided for @premiumRequired.
  ///
  /// In en, this message translates to:
  /// **'Premium required'**
  String get premiumRequired;

  /// No description provided for @removeLastRow.
  ///
  /// In en, this message translates to:
  /// **'Remove last row'**
  String get removeLastRow;

  /// No description provided for @removeLastColumn.
  ///
  /// In en, this message translates to:
  /// **'Remove last column'**
  String get removeLastColumn;

  /// No description provided for @removeLastRowQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove last row?'**
  String get removeLastRowQuestion;

  /// No description provided for @removeLastColumnQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove last column?'**
  String get removeLastColumnQuestion;

  /// No description provided for @tableRemovalMessage.
  ///
  /// In en, this message translates to:
  /// **'The text in these cells will be deleted.'**
  String get tableRemovalMessage;

  /// No description provided for @addRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get addRow;

  /// No description provided for @addColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get addColumn;

  /// No description provided for @bullets.
  ///
  /// In en, this message translates to:
  /// **'Bullets'**
  String get bullets;

  /// No description provided for @dashes.
  ///
  /// In en, this message translates to:
  /// **'Dashes'**
  String get dashes;

  /// No description provided for @squares.
  ///
  /// In en, this message translates to:
  /// **'Squares'**
  String get squares;

  /// No description provided for @numbers.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get numbers;

  /// No description provided for @letters.
  ///
  /// In en, this message translates to:
  /// **'Letters'**
  String get letters;

  /// No description provided for @romanNumerals.
  ///
  /// In en, this message translates to:
  /// **'Roman numerals'**
  String get romanNumerals;

  /// No description provided for @categoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} subcategory} other{{count} subcategories}}'**
  String categoryCount(int count);

  /// No description provided for @entryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} entry} other{{count} entries}}'**
  String entryCount(int count);

  /// No description provided for @graphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get graphite;

  /// No description provided for @blue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get blue;

  /// No description provided for @green.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get green;

  /// No description provided for @purple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get purple;

  /// No description provided for @slate.
  ///
  /// In en, this message translates to:
  /// **'Slate'**
  String get slate;

  /// No description provided for @sage.
  ///
  /// In en, this message translates to:
  /// **'Sage'**
  String get sage;

  /// No description provided for @linen.
  ///
  /// In en, this message translates to:
  /// **'Linen'**
  String get linen;

  /// No description provided for @ocean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get ocean;

  /// No description provided for @forest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get forest;

  /// No description provided for @geometry.
  ///
  /// In en, this message translates to:
  /// **'Geometry'**
  String get geometry;

  /// No description provided for @dusk.
  ///
  /// In en, this message translates to:
  /// **'Dusk'**
  String get dusk;

  /// No description provided for @rose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get rose;

  /// No description provided for @entryDates.
  ///
  /// In en, this message translates to:
  /// **'Created {created} · Edited {edited}'**
  String entryDates(String created, String edited);

  /// No description provided for @opacityPercent.
  ///
  /// In en, this message translates to:
  /// **'Interface opacity · {percent}%'**
  String opacityPercent(int percent);

  /// No description provided for @couldNotSaveTheImageLayoutPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not save the image layout. Please try again.'**
  String get couldNotSaveTheImageLayoutPleaseTryAgain;

  /// No description provided for @couldNotSaveTheNoteSize.
  ///
  /// In en, this message translates to:
  /// **'Could not save the note size.'**
  String get couldNotSaveTheNoteSize;

  /// No description provided for @couldNotUpdateThePreviewPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not update the preview. Please try again.'**
  String get couldNotUpdateThePreviewPleaseTryAgain;

  /// No description provided for @couldNotSaveYourBackgroundPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not save your background. Please try again.'**
  String get couldNotSaveYourBackgroundPleaseTryAgain;

  /// No description provided for @couldNotUpdateYourPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not update your photo.'**
  String get couldNotUpdateYourPhoto;

  /// No description provided for @couldNotCropThisPhotoTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not crop this photo. Try again.'**
  String get couldNotCropThisPhotoTryAgain;

  /// No description provided for @couldNotRenderThePhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not render the photo.'**
  String get couldNotRenderThePhoto;

  /// No description provided for @chooseAPhotoSmallerThan20Mb.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo smaller than 20 MB.'**
  String get chooseAPhotoSmallerThan20Mb;

  /// No description provided for @chooseAPhotoUpTo16000PixelsOnEachSide.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo up to 16,000 pixels on each side.'**
  String get chooseAPhotoUpTo16000PixelsOnEachSide;

  /// No description provided for @privateStorageIsUnavailableOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Private storage is unavailable on this device.'**
  String get privateStorageIsUnavailableOnThisDevice;

  /// No description provided for @couldNotUnlockPrivateInformationPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock private information. Please try again.'**
  String get couldNotUnlockPrivateInformationPleaseTryAgain;

  /// No description provided for @couldNotSaveThePrivatePasswordPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not save the private password. Please try again.'**
  String get couldNotSaveThePrivatePasswordPleaseTryAgain;

  /// No description provided for @biometricAccessIsUnavailableOrWasCancelledUseYourPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Biometric access is unavailable or was cancelled. Use your private password.'**
  String get biometricAccessIsUnavailableOrWasCancelledUseYourPrivatePassword;

  /// No description provided for @biometricsAreUnavailableUnlockWithYourPrivatePasswordToSetThemUpAgain.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are unavailable. Unlock with your private password to set them up again.'**
  String
  get biometricsAreUnavailableUnlockWithYourPrivatePasswordToSetThemUpAgain;

  /// No description provided for @biometricsCouldNotBeSetUpCheckYourDeviceSettingsOrTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Biometrics could not be set up. Check your device settings or try again.'**
  String get biometricsCouldNotBeSetUpCheckYourDeviceSettingsOrTryAgain;

  /// No description provided for @couldNotLoadStartupPreferencesPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not load startup preferences. Please try again.'**
  String get couldNotLoadStartupPreferencesPleaseTryAgain;

  /// No description provided for @couldNotOpenTheApp.
  ///
  /// In en, this message translates to:
  /// **'Could not open the app.'**
  String get couldNotOpenTheApp;

  /// No description provided for @couldNotSaveTheEntryYourTextIsStillInTheForm.
  ///
  /// In en, this message translates to:
  /// **'Could not save the entry. Your text is still in the form.'**
  String get couldNotSaveTheEntryYourTextIsStillInTheForm;

  /// No description provided for @couldNotSaveTheAttachmentsPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not save the attachments. Please try again.'**
  String get couldNotSaveTheAttachmentsPleaseTryAgain;

  /// No description provided for @couldNotReadTheSelectedFilesPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected files. Please try again.'**
  String get couldNotReadTheSelectedFilesPleaseTryAgain;

  /// No description provided for @couldNotDeleteTheEntry.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the entry.'**
  String get couldNotDeleteTheEntry;

  /// No description provided for @couldNotDeleteCategoryPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not delete category. Please try again.'**
  String get couldNotDeleteCategoryPleaseTryAgain;

  /// No description provided for @couldNotLoadDeletionDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not load deletion details'**
  String get couldNotLoadDeletionDetails;

  /// No description provided for @categoriesAreNotReadyPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Categories are not ready. Please try again.'**
  String get categoriesAreNotReadyPleaseTryAgain;

  /// No description provided for @failedToSaveCategory.
  ///
  /// In en, this message translates to:
  /// **'Failed to save category.'**
  String get failedToSaveCategory;

  /// No description provided for @retryLoadingCategories.
  ///
  /// In en, this message translates to:
  /// **'Retry loading categories'**
  String get retryLoadingCategories;

  /// No description provided for @failedToLoadCategories.
  ///
  /// In en, this message translates to:
  /// **'Failed to load categories'**
  String get failedToLoadCategories;

  /// No description provided for @failedToPickAnImagePleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick an image. Please try again.'**
  String get failedToPickAnImagePleaseTryAgain;

  /// No description provided for @couldNotPauseOrResumeTheRecording.
  ///
  /// In en, this message translates to:
  /// **'Could not pause or resume the recording.'**
  String get couldNotPauseOrResumeTheRecording;

  /// No description provided for @couldNotCompleteTheAudioAction.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the audio action.'**
  String get couldNotCompleteTheAudioAction;

  /// No description provided for @couldNotChangePlaybackSpeedForThisAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Could not change playback speed for this audio file.'**
  String get couldNotChangePlaybackSpeedForThisAudioFile;

  /// No description provided for @couldNotSeekThisAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Could not seek this audio file.'**
  String get couldNotSeekThisAudioFile;

  /// No description provided for @couldNotStopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Could not stop playback.'**
  String get couldNotStopPlayback;

  /// No description provided for @finishUnlockingOrSavingPrivateInformationFirst.
  ///
  /// In en, this message translates to:
  /// **'Finish unlocking or saving private information first.'**
  String get finishUnlockingOrSavingPrivateInformationFirst;

  /// No description provided for @couldNotProtectTheLatestEditPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not protect the latest edit. Please try again.'**
  String get couldNotProtectTheLatestEditPleaseTryAgain;

  /// No description provided for @couldNotProtectTheLatestEditUnlockToCheckAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not protect the latest edit. Unlock to check and try again.'**
  String get couldNotProtectTheLatestEditUnlockToCheckAndTryAgain;

  /// No description provided for @couldNotKeepTheLatestPrivateEditPleaseUnlockAndCheckIt.
  ///
  /// In en, this message translates to:
  /// **'Could not keep the latest private edit. Please unlock and check it.'**
  String get couldNotKeepTheLatestPrivateEditPleaseUnlockAndCheckIt;

  /// No description provided for @keepYourEntriesAndImportDifferingDriveEntriesAsCopies.
  ///
  /// In en, this message translates to:
  /// **'Keep your entries and import differing Drive entries as copies.'**
  String get keepYourEntriesAndImportDifferingDriveEntriesAsCopies;

  /// No description provided for @yourLocalEntriesAndProfileStayInPlaceDifferentEntriesFromGoogleDriveAreAddedToAGoogleDriveCopiesCategoryWithTh.
  ///
  /// In en, this message translates to:
  /// **'Your local entries and profile stay in place. Different entries from Google Drive are added to a Google Drive copies category, with their attachments.'**
  String
  get yourLocalEntriesAndProfileStayInPlaceDifferentEntriesFromGoogleDriveAreAddedToAGoogleDriveCopiesCategoryWithTh;

  /// No description provided for @unlockToView.
  ///
  /// In en, this message translates to:
  /// **'•••••••• · Unlock to view'**
  String get unlockToView;

  /// No description provided for @thisEntryIsNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This entry is no longer available'**
  String get thisEntryIsNoLongerAvailable;

  /// No description provided for @showMoreLevels.
  ///
  /// In en, this message translates to:
  /// **'Show more levels'**
  String get showMoreLevels;

  /// No description provided for @couldNotLoadEntries.
  ///
  /// In en, this message translates to:
  /// **'Could not load entries. Please try again.'**
  String get couldNotLoadEntries;

  /// No description provided for @couldNotUpdateFlag.
  ///
  /// In en, this message translates to:
  /// **'Could not update the flag.'**
  String get couldNotUpdateFlag;

  /// No description provided for @tutorialSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Tutorial closed, but progress could not be saved. It may appear again next time.'**
  String get tutorialSaveFailed;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get switchAccount;

  /// No description provided for @addGoogleAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Google account'**
  String get addGoogleAccount;

  /// No description provided for @editProfileName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editProfileName;

  /// No description provided for @moveGuestEntries.
  ///
  /// In en, this message translates to:
  /// **'Move guest entries'**
  String get moveGuestEntries;

  /// No description provided for @moveGuestEntriesDescription.
  ///
  /// In en, this message translates to:
  /// **'Move guest entries on this device to {email}? Entries with private information stay in Guest.'**
  String moveGuestEntriesDescription(String email);

  /// No description provided for @entriesFromThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Entries from this device'**
  String get entriesFromThisDevice;

  /// No description provided for @chooseWorkspaceGoogleAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose the Google account for this workspace.'**
  String get chooseWorkspaceGoogleAccount;

  /// No description provided for @guestEntriesChangedDuringTransfer.
  ///
  /// In en, this message translates to:
  /// **'Some guest entries changed during transfer. Both copies are safe.'**
  String get guestEntriesChangedDuringTransfer;

  /// No description provided for @setUpScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Set up a screen lock'**
  String get setUpScreenLock;

  /// No description provided for @screenLockSetupInstructions.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN, pattern, or passcode in your phone’s security settings, then come back and try again.'**
  String get screenLockSetupInstructions;

  /// No description provided for @screenLockNeedsPriorUnlock.
  ///
  /// In en, this message translates to:
  /// **'Screen lock access is unavailable for these entries on this phone. Try a device where you’ve previously opened them, or use your private password.'**
  String get screenLockNeedsPriorUnlock;

  /// No description provided for @couldNotVerifyScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Could not verify your screen lock. Try again or unlock with your private password.'**
  String get couldNotVerifyScreenLock;

  /// No description provided for @enterPasswordOrUseScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Enter your private password or unlock with this phone.'**
  String get enterPasswordOrUseScreenLock;

  /// No description provided for @privatePasswordUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unlock your private information on a device where it’s already available.'**
  String get privatePasswordUnavailable;

  /// No description provided for @addPrivateLogin.
  ///
  /// In en, this message translates to:
  /// **'Add login and password'**
  String get addPrivateLogin;

  /// No description provided for @privateLoginAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Login and password'**
  String get privateLoginAndPassword;

  /// No description provided for @privateLoginLabel.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get privateLoginLabel;

  /// No description provided for @privateEntryPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get privateEntryPassword;

  /// No description provided for @showPrivateEntryPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPrivateEntryPassword;

  /// No description provided for @hidePrivateEntryPassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePrivateEntryPassword;

  /// No description provided for @copyPrivateLogin.
  ///
  /// In en, this message translates to:
  /// **'Copy login'**
  String get copyPrivateLogin;

  /// No description provided for @copyPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get copyPrivatePassword;

  /// No description provided for @privateLoginCopied.
  ///
  /// In en, this message translates to:
  /// **'Login copied'**
  String get privateLoginCopied;

  /// No description provided for @privatePasswordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get privatePasswordCopied;

  /// No description provided for @couldNotCopyPrivateValue.
  ///
  /// In en, this message translates to:
  /// **'Could not copy. Try again.'**
  String get couldNotCopyPrivateValue;

  /// No description provided for @googleDriveReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect Google Drive to resume syncing.'**
  String get googleDriveReconnect;

  /// No description provided for @localPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Private password on this device'**
  String get localPrivatePassword;

  /// No description provided for @driveCopyPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Private password for Drive copy {copy}'**
  String driveCopyPrivatePassword(int copy);

  /// No description provided for @incorrectPrivateMergePassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect private password.'**
  String get incorrectPrivateMergePassword;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'pl', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pl':
      return AppLocalizationsPl();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
