/* roadmap_general_settings.m
 *
 * LICENSE:
 *
 *   Copyright 2009 Avi R.
 *   Copyright 2009, Waze Ltd
 *
 *   RoadMap is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License V2 as published by
 *   the Free Software Foundation.
 *
 *   RoadMap is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with RoadMap; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "roadmap.h"
#include "roadmap_config.h"
#include "cost_preferences.h"
#include "roadmap_iphonegeneral_settings.h"
#include "widgets/iphoneCell.h"
#include "widgets/iphoneCellSwitch.h"
#include "widgets/iphoneCellSelect.h"
#include "roadmap_checklist.h"
#include "roadmap_factory.h"
#include "roadmap_start.h"
#include "roadmap_lang.h"
#include "roadmap_prompts.h"
#include "roadmap_alternative_routes.h"
#include "roadmap_main.h"
#include "roadmap_iphonemain.h"
#include "roadmap_math.h"
#include "roadmap_device.h"
#include "roadmap_skin.h"
#include "roadmap_device_events.h"
#include "roadmap_sound.h"
#include "ssd/ssd_confirm_dialog.h"
#include "ssd/ssd_progress_msg_dialog.h"
#include "Realtime.h"
#include "roadmap_push_notifications.h"
#include "roadmap_messagebox.h"


#define CLOCK_SETTINGS_12_HOUR "12 hr."
#define CLOCK_SETTINGS_24_HOUR "24 hr."

static const char*   title = "General settings";

static RoadMapConfigDescriptor RoadMapConfigBackLight =
      ROADMAP_CONFIG_ITEM("Display", "BackLight");
extern RoadMapConfigDescriptor NavigateConfigAutoZoom;
static RoadMapConfigDescriptor RoadMapConfigShowTicker =
		ROADMAP_CONFIG_ITEM("User", "Show points ticker");
static RoadMapConfigDescriptor RoadMapConfigGeneralUnit =
      ROADMAP_CONFIG_ITEM("General", "Unit");
static RoadMapConfigDescriptor RoadMapConfigGeneralUserUnit =
                        ROADMAP_CONFIG_ITEM("General", "Unit");

RoadMapConfigDescriptor RoadMapConfigUseNativeKeyboard =
      ROADMAP_CONFIG_ITEM("Keyboard", "Use native");

RoadMapConfigDescriptor RoadMapConfigEventsRadius =
      ROADMAP_CONFIG_ITEM("Events", "Radius");

RoadMapConfigDescriptor RoadMapConfigClockFormat = 
      ROADMAP_CONFIG_ITEM("Clock","Format");



enum IDs {
   ID_BACKLIGHT = 1,
	ID_AUTO_ZOOM,
	ID_TICKER,
	ID_UNIT,
	ID_AUTO_NIGHT_MODE,
   ID_SHOW_ICONS,
   ID_LANGUAGES,
   ID_PROMPTS,
   ID_CLOCK_FORMAT,
   ID_SUGGEST_ROUTES,
   ID_REDIRECT_SPEAKER,
   ID_NOTIFICATIONS,
   ID_EVENTS_RADIUS
};

#define MAX_IDS 25

static RoadMapCallback id_callbacks[MAX_IDS];
static RoadMapCallback lang_loaded_callback = NULL;
static const char *distance_labels[6];
static const char *distance_values[6];
static const char *zoom_labels[3];
static const char *zoom_values[3];


int roadmap_general_settings_events_radius(void){
   return roadmap_config_get_integer(&RoadMapConfigEventsRadius);
}


BOOL roadmap_general_settings_is_24_hour_clock() {
   return roadmap_config_match(&RoadMapConfigClockFormat, CLOCK_SETTINGS_24_HOUR);
}


static void language_callback (int value, int group) {
   char text[256];
   const void ** lang_values = roadmap_lang_get_available_langs_values();
   
   roadmap_lang_set_system_lang(lang_values[value]);
   roadmap_lang_reload();
   
	roadmap_main_show_root(NO);
   
   snprintf(text, sizeof(text), "%s: %s\n%s: %s",
            roadmap_lang_get ("Language"),
            roadmap_lang_get (roadmap_lang_get_label(roadmap_lang_get_system_lang())),
            roadmap_lang_get ("Prompts"),
            roadmap_lang_get (roadmap_prompts_get_label(roadmap_prompts_get_name())));
   roadmap_messagebox("",text);
}

static void language_callback_initial (int value, int group) {
   const void ** lang_values = roadmap_lang_get_available_langs_values();
   RoadMapCallback lang_loaded = lang_loaded_callback;
   lang_loaded_callback = NULL;
   
   roadmap_main_pop_view(YES);
   
   ssd_progress_msg_dialog_show("Downloading language");
   roadmap_lang_set_system_lang(lang_values[value]);
   roadmap_lang_download_lang_file(roadmap_lang_get_system_lang(), lang_loaded);
}

static void show_languages_internal (BOOL initial) {
   const void ** lang_values = roadmap_lang_get_available_langs_values();
   const char ** lang_labels = roadmap_lang_get_available_langs_labels();
   int lang_count = roadmap_lang_get_available_langs_count();
   int i;
   
   NSMutableArray *dataArray = [NSMutableArray arrayWithCapacity:1];
	NSMutableArray *groupArray = NULL;
   NSMutableDictionary *dict = NULL;
   NSString *text;
   NSNumber *accessoryType = [NSNumber numberWithInt:UITableViewCellAccessoryCheckmark];
   RoadMapChecklist *langView;
   
   groupArray = [NSMutableArray arrayWithCapacity:1];
   
   for (i = 0; i < lang_count; ++i) {
      dict = [NSMutableDictionary dictionaryWithCapacity:1];
      text = [NSString stringWithUTF8String:roadmap_lang_get(lang_labels[i])];
      [dict setValue:text forKey:@"text"];
      if (!initial && strcmp(lang_values[i], roadmap_lang_get_system_lang()) == 0) {
         [dict setObject:accessoryType forKey:@"accessory"];
      }
      [dict setValue:[NSNumber numberWithInt:1] forKey:@"selectable"];
      [groupArray addObject:dict];
   }
   [dataArray addObject:groupArray];
   
   text = [NSString stringWithUTF8String:roadmap_lang_get ("Language")];
   
   if (!initial)
      langView = [[RoadMapChecklist alloc] 
                  activateWithTitle:text andData:dataArray andHeaders:NULL
                  andCallback:language_callback andHeight:60 andFlags:0];
   else      
      langView = [[RoadMapChecklist alloc] 
                  activateWithTitle:text andData:dataArray andHeaders:NULL
                  andCallback:language_callback_initial andHeight:60 andFlags:CHECKLIST_DISABLE_BACK];
}

static void on_download_lang_confirm(int exit_code, void *context){
   if (exit_code == dec_yes){
      const char *prompt = (const char *)context;
      roadmap_prompts_set_name(prompt);
      roadmap_prompts_download(prompt);
   }
}

static void show_languages () {
   show_languages_internal (FALSE);
}
void roadmap_general_settings_show_lang_initial(RoadMapCallback callback) {
   lang_loaded_callback = callback;
   show_languages_internal (TRUE);
}

static void prompts_callback (int value, int group) {
   const char ** prompts_labels = roadmap_prompts_get_labels();
   if (!roadmap_prompts_exist(roadmap_prompts_get_prompt_value_from_name(prompts_labels[value]))){
      char msg[256];
      snprintf(msg, sizeof(msg),"%s %s, %s", roadmap_lang_get("Prompt set"), roadmap_lang_get(prompts_labels[value]), roadmap_lang_get("is not installed on your device, Do you want to download prompt files?") );
      ssd_confirm_dialog("", msg, FALSE, on_download_lang_confirm, (void *)roadmap_prompts_get_prompt_value_from_name(prompts_labels[value]));
      roadmap_main_show_root(NO);
   } else {
      roadmap_prompts_set_name(roadmap_prompts_get_prompt_value_from_name(prompts_labels[value]));
      roadmap_main_pop_view(YES);
   }
}

static void show_prompts() {
   const void ** prompts_values = roadmap_prompts_get_values();
   const char ** prompts_labels = roadmap_prompts_get_labels();
   int prompts_count = roadmap_prompts_get_count();   
   int i;
   
   NSMutableArray *dataArray = [NSMutableArray arrayWithCapacity:1];
	NSMutableArray *groupArray = NULL;
   NSMutableDictionary *dict = NULL;
   NSString *text;
   NSNumber *accessoryType = [NSNumber numberWithInt:UITableViewCellAccessoryCheckmark];
   RoadMapChecklist *promptsView;
   
   groupArray = [NSMutableArray arrayWithCapacity:1];
   
   for (i = 0; i < prompts_count; ++i) {
      dict = [NSMutableDictionary dictionaryWithCapacity:1];
      text = [NSString stringWithUTF8String:roadmap_lang_get(prompts_labels[i])];
      [dict setValue:text forKey:@"text"];
      if (strcmp(prompts_values[i], roadmap_prompts_get_name()) == 0) {
         [dict setObject:accessoryType forKey:@"accessory"];
      }
      [dict setValue:[NSNumber numberWithInt:1] forKey:@"selectable"];
      [groupArray addObject:dict];
   }
   [dataArray addObject:groupArray];
   
   text = [NSString stringWithUTF8String:roadmap_lang_get ("Prompts")];
	promptsView = [[RoadMapChecklist alloc] 
                  activateWithTitle:text andData:dataArray andHeaders:NULL
                  andCallback:prompts_callback andHeight:60 andFlags:0];
   
}

static void zoom_callback (int value, int group) {
   
   if (!(roadmap_config_match(&NavigateConfigAutoZoom, zoom_values[value]))){ // descriptor changed
      roadmap_config_set (&NavigateConfigAutoZoom,zoom_values[value]);
   }
   
   roadmap_main_pop_view(YES);
}

static void show_zoom() {
   static BOOL initialized = FALSE;
   int i;
   
   NSMutableArray *dataArray = [NSMutableArray arrayWithCapacity:1];
	NSMutableArray *groupArray = NULL;
   NSMutableDictionary *dict = NULL;
   NSString *text;
   NSNumber *accessoryType = [NSNumber numberWithInt:UITableViewCellAccessoryCheckmark];
   RoadMapChecklist *zoomView;
   
   if (!initialized) {
      zoom_values[0] = "speed";
      zoom_values[1] = "yes";
      zoom_values[2] = "no";
      zoom_labels[0] = roadmap_lang_get("According to speed");
      zoom_labels[1] = roadmap_lang_get("According to distance");
      zoom_labels[2] = roadmap_lang_get("No");
      
      initialized = TRUE;
   }
   
   groupArray = [NSMutableArray arrayWithCapacity:1];
   
   for (i = 0; i < 3; ++i) {
      dict = [NSMutableDictionary dictionaryWithCapacity:1];
      text = [NSString stringWithUTF8String:zoom_labels[i]];
      [dict setValue:text forKey:@"text"];
      if (roadmap_config_match(&NavigateConfigAutoZoom, zoom_values[i])) {
         [dict setObject:accessoryType forKey:@"accessory"];
      }
      [dict setValue:[NSNumber numberWithInt:1] forKey:@"selectable"];
      [groupArray addObject:dict];
   }
   [dataArray addObject:groupArray];
   
   text = [NSString stringWithUTF8String:roadmap_lang_get ("Auto zoom")];
	zoomView = [[RoadMapChecklist alloc] 
                  activateWithTitle:text andData:dataArray andHeaders:NULL
                  andCallback:zoom_callback andHeight:60 andFlags:0];
   
}

static void events_callback (int value, int group) {
   if (!(roadmap_config_match(&RoadMapConfigEventsRadius, distance_values[value]))){ // descriptor changed
      roadmap_config_set (&RoadMapConfigEventsRadius,distance_values[value]);
      OnSettingsChanged_VisabilityGroup(); // notify server of visibilaty settings change
   }
   
   roadmap_main_pop_view(YES);
}

static void show_events_radius() {
   static BOOL initialized = FALSE;
   int i;
   
   NSMutableArray *dataArray = [NSMutableArray arrayWithCapacity:1];
	NSMutableArray *groupArray = NULL;
   NSMutableDictionary *dict = NULL;
   NSString *text;
   NSNumber *accessoryType = [NSNumber numberWithInt:UITableViewCellAccessoryCheckmark];
   RoadMapChecklist *promptsView;
   
   if (!initialized) {
      if (roadmap_math_is_metric()){
         char temp[100];
         
         distance_values[0] = "5";
         distance_values[1] = "25";
         distance_values[2] = "50";
         distance_values[3] = "100";
         distance_values[4] = "200";
         distance_values[5] = "-1";
         snprintf(temp, 100, "5 %s", roadmap_lang_get("Km"));
         distance_labels[0] = strdup(temp);
         snprintf(temp, 100, "25 %s", roadmap_lang_get("Km"));
         distance_labels[1] = strdup(temp);
         snprintf(temp, 100, "50 %s", roadmap_lang_get("Km"));
         distance_labels[2] = strdup(temp);
         snprintf(temp, 100, "100 %s", roadmap_lang_get("Km"));
         distance_labels[3] = strdup(temp);
         snprintf(temp, 100, "200 %s", roadmap_lang_get("Km"));
         distance_labels[4] = strdup(temp);
         distance_labels[5] = roadmap_lang_get("All");
      }
      else{
         char temp[100];
         
         distance_values[0] = "8";
         distance_values[1] = "40";
         distance_values[2] = "80";
         distance_values[3] = "160";
         distance_values[4] = "320";
         distance_values[5] = "-1";
         snprintf(temp, 100, "5 %s", roadmap_lang_get("miles"));
         distance_labels[0] = strdup(temp);
         snprintf(temp, 100, "25 %s", roadmap_lang_get("miles"));
         distance_labels[1] = strdup(temp);
         snprintf(temp, 100, "50 %s", roadmap_lang_get("miles"));
         distance_labels[2] = strdup(temp);
         snprintf(temp, 100, "100 %s", roadmap_lang_get("miles"));
         distance_labels[3] = strdup(temp);
         snprintf(temp, 100, "200 %s", roadmap_lang_get("miles"));
         distance_labels[4] = strdup(temp);
         distance_labels[5] = roadmap_lang_get("All");
      }     
      
      initialized = TRUE;
   }
   
   groupArray = [NSMutableArray arrayWithCapacity:1];
   
   for (i = 0; i < 6; ++i) {
      dict = [NSMutableDictionary dictionaryWithCapacity:1];
      text = [NSString stringWithUTF8String:distance_labels[i]];
      [dict setValue:text forKey:@"text"];
      if (roadmap_config_match(&RoadMapConfigEventsRadius, distance_values[i])) {
         [dict setObject:accessoryType forKey:@"accessory"];
      }
      [dict setValue:[NSNumber numberWithInt:1] forKey:@"selectable"];
      [groupArray addObject:dict];
   }
   [dataArray addObject:groupArray];
   
   text = [NSString stringWithUTF8String:roadmap_lang_get ("Events Radius")];
	promptsView = [[RoadMapChecklist alloc] 
                  activateWithTitle:text andData:dataArray andHeaders:NULL
                  andCallback:events_callback andHeight:60 andFlags:0];
   
}

void roadmap_general_settings_init(void){
   
   roadmap_config_declare
      ("user", &RoadMapConfigBackLight, "yes", NULL);
   
   roadmap_config_declare_enumeration
      ("preferences", &RoadMapConfigGeneralUnit, NULL, "imperial", "metric", NULL);

   roadmap_config_declare_enumeration
      ("user", &RoadMapConfigGeneralUserUnit, NULL, "default", "imperial", "metric", NULL);
   
   roadmap_config_declare_enumeration
      ("user", &RoadMapConfigShowTicker, NULL, "yes", "no", NULL);
   
   roadmap_config_declare_enumeration
      ("user", &RoadMapConfigClockFormat, NULL, CLOCK_SETTINGS_12_HOUR, CLOCK_SETTINGS_24_HOUR, NULL);
   
   roadmap_config_declare_enumeration
      ("user", &RoadMapConfigEventsRadius, NULL, "-1", "5", "25", "50", "100", "200", NULL);
}


void roadmap_general_settings_show (void) {
		GeneralSetingsDialog *dialog = [[GeneralSetingsDialog alloc] initWithStyle:UITableViewStyleGrouped];
		[dialog show];
}



@implementation GeneralSetingsDialog
@synthesize dataArray;

- (id)initWithStyle:(UITableViewStyle)style
{
   int i;
	static int initialized = 0;
   
	self = [super initWithStyle:style];
	
	dataArray = [[NSMutableArray arrayWithCapacity:1] retain];
   
   if (!initialized) {
		for (i=0; i < MAX_IDS; ++i) {
			id_callbacks[i] = NULL;
		}
		initialized = 1;
	}
	
	return self;
}

- (void)viewWillAppear:(BOOL)animated
{
   UITableView *tableView = [self tableView];
   iphoneCell *cell;
   
   cell = (iphoneCell *)[tableView viewWithTag:ID_PROMPTS];
   if (cell){
      cell.rightLabel.text = [NSString stringWithUTF8String:roadmap_lang_get 
                                      (roadmap_prompts_get_label(roadmap_prompts_get_name()))];
      [cell setNeedsLayout];
   }
      
}

- (void) viewDidLoad
{
	UITableView *tableView = [self tableView];
	
   roadmap_main_set_table_color(tableView);
   tableView.rowHeight = 50;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
   return roadmap_main_should_rotate (interfaceOrientation);
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
   roadmap_device_event_notification( device_event_window_orientation_changed);
}


- (void) onClose
{
   roadmap_main_show_root(0);
}

- (void) populateData
{
	NSMutableArray *groupArray = NULL;
   iphoneCell *callbackCell = NULL;
	iphoneCellSwitch *swCell = NULL;
	iphoneCellSelect *selCell = NULL;
	NSArray *segmentsArray = NULL;
	
   int lang_count = roadmap_lang_get_available_langs_count();
   int prompts_count = roadmap_prompts_get_count();
   
   //Group #1
   groupArray = [NSMutableArray arrayWithCapacity:1];
   
   //Languages
   if (lang_count > 1){
      callbackCell = [[[iphoneCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"actionCell"] autorelease];
      [callbackCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
      [callbackCell setTag:ID_LANGUAGES];
      id_callbacks[ID_LANGUAGES] = show_languages;
      callbackCell.textLabel.text = [NSString stringWithUTF8String:roadmap_lang_get ("Language")];
      callbackCell.rightLabel.text = [NSString stringWithUTF8String:roadmap_lang_get 
                                      (roadmap_lang_get_label(roadmap_lang_get_system_lang()))];
      [groupArray addObject:callbackCell];
   }
   
   //Prompts
   if (prompts_count > 0){
      callbackCell = [[[iphoneCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"actionCell"] autorelease];
      [callbackCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
      [callbackCell setTag:ID_PROMPTS];
      id_callbacks[ID_PROMPTS] = show_prompts;
      callbackCell.textLabel.text = [NSString stringWithUTF8String:roadmap_lang_get ("Prompts")];
      callbackCell.rightLabel.text = [NSString stringWithUTF8String:roadmap_lang_get 
                                      (roadmap_prompts_get_label(roadmap_prompts_get_name()))];
      [groupArray addObject:callbackCell];
   }
   
   //Units
   selCell = [[[iphoneCellSelect alloc] initWithFrame:CGRectZero reuseIdentifier:@"selectCell"] autorelease];
   [selCell setLabel:[NSString stringWithUTF8String:roadmap_lang_get ("Measurement system")]];
   segmentsArray = [NSArray arrayWithObjects:[NSString stringWithUTF8String:roadmap_lang_get("Meters")],
                                             [NSString stringWithUTF8String:roadmap_lang_get("Miles")],
                                             NULL];
   [selCell setItems:segmentsArray];
   
   if (roadmap_config_match(&RoadMapConfigGeneralUserUnit, "default")){
   	 if (roadmap_config_match(&RoadMapConfigGeneralUnit, "metric"))
      	[selCell setSelectedSegment:0];
   	 else
        [selCell setSelectedSegment:1];
   }
   else{
   	 if (roadmap_config_match(&RoadMapConfigGeneralUserUnit, "metric"))
      	[selCell setSelectedSegment:0];
   	 else
        [selCell setSelectedSegment:1];
   }
   [selCell setTag:ID_UNIT];
   [selCell setDelegate:self];
   [groupArray addObject:selCell];
   
   //Clock format
   swCell = [[[iphoneCellSwitch alloc] initWithFrame:CGRectZero reuseIdentifier:@"switchCell"] autorelease];
	[swCell setTag:ID_CLOCK_FORMAT];
	[swCell setLabel:[NSString stringWithUTF8String:roadmap_lang_get 
                     ("24 hour clock")]];
	[swCell setDelegate:self];
	[swCell setState: roadmap_config_match(&RoadMapConfigClockFormat, CLOCK_SETTINGS_24_HOUR)];
	[groupArray addObject:swCell];
   
   [dataArray addObject:groupArray];
   
   
   //Group #2
   groupArray = [NSMutableArray arrayWithCapacity:1];
   
   //Auto zoom
   callbackCell = [[[iphoneCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"actionCell"] autorelease];
   [callbackCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
   [callbackCell setTag:ID_AUTO_ZOOM];
   id_callbacks[ID_AUTO_ZOOM] = show_zoom;
   callbackCell.textLabel.text = [NSString stringWithUTF8String:roadmap_lang_get ("Auto zoom")];
   //TODO: add right label for auto zoom
   //callbackCell.rightLabel.text = [NSString stringWithUTF8String:roadmap_lang_get 
//                                   (roadmap_prompts_get_label(roadmap_prompts_get_name()))];
   [groupArray addObject:callbackCell];
   
   //Show ticker
	swCell = [[[iphoneCellSwitch alloc] initWithFrame:CGRectZero reuseIdentifier:@"switchCell"] autorelease];
	[swCell setTag:ID_TICKER];
	[swCell setLabel:[NSString stringWithUTF8String:roadmap_lang_get 
                     ("Show points ticker")]];
	[swCell setDelegate:self];
	[swCell setState: roadmap_config_match(&RoadMapConfigShowTicker, "yes")];
	[groupArray addObject:swCell];
   
   //Backlight
	swCell = [[[iphoneCellSwitch alloc] initWithFrame:CGRectZero reuseIdentifier:@"switchCell"] autorelease];
	[swCell setTag:ID_BACKLIGHT];
	[swCell setLabel:[NSString stringWithUTF8String:roadmap_lang_get 
                     ("Back Light On")]];
	[swCell setDelegate:self];
	[swCell setState: roadmap_config_match (&RoadMapConfigBackLight, "yes")];
	[groupArray addObject:swCell];
   
   //Automatically suggest routes
   if (roadmap_alternative_feature_enabled()){
      swCell = [[[iphoneCellSwitch alloc] initWithFrame:CGRectZero reuseIdentifier:@"switchCell"] autorelease];
      [swCell setTag:ID_SUGGEST_ROUTES];
      [swCell setLabel:[NSString stringWithUTF8String:roadmap_lang_get 
                        ("Auto-learn routes to your frequent destination")]];
      [swCell setDelegate:self];
      [swCell setState: roadmap_alternative_routes_suggest_routes()];
      [groupArray addObject:swCell];
   }
   
   //Redirect sound to speaker
   if (roadmap_alternative_feature_enabled()){
      swCell = [[[iphoneCellSwitch alloc] initWithFrame:CGRectZero reuseIdentifier:@"switchCell"] autorelease];
      [swCell setTag:ID_REDIRECT_SPEAKER];
      [swCell setLabel:[NSString stringWithUTF8String:roadmap_lang_get 
                        ("Always play sound to speaker")]];
      [swCell setDelegate:self];
      [swCell setState: roadmap_sound_is_route_to_speaker()];
      [groupArray addObject:swCell];
   }
   
   [dataArray addObject:groupArray];
   
   
   //Group #3
   groupArray = [NSMutableArray arrayWithCapacity:1];
   
   //events radius
   callbackCell = [[[iphoneCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"actionCell"] autorelease];
   [callbackCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
   [callbackCell setTag:ID_EVENTS_RADIUS];
   id_callbacks[ID_EVENTS_RADIUS] = show_events_radius;
   callbackCell.textLabel.text = [NSString stringWithUTF8String:roadmap_lang_get ("Events Radius")];
   //callbackCell.rightLabel.text = [NSString stringWithUTF8String:roadmap_lang_get 
   //                                (roadmap_prompts_get_label(roadmap_prompts_get_name()))];
   [groupArray addObject:callbackCell];
   
   //push notifications
   callbackCell = [[[iphoneCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"actionCell"] autorelease];
   [callbackCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
   [callbackCell setTag:ID_NOTIFICATIONS];
   id_callbacks[ID_NOTIFICATIONS] = roadmap_push_notifications_settings;
   callbackCell.textLabel.text = [NSString stringWithUTF8String:roadmap_lang_get ("Notifications")];
   [groupArray addObject:callbackCell];
	
	
	[dataArray addObject:groupArray];
}


- (void) show
{
	[self populateData];

	[self setTitle:[NSString stringWithUTF8String:roadmap_lang_get(title)]];
   
   //set right button
	UINavigationItem *navItem = [self navigationItem];
   UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithUTF8String:roadmap_lang_get("Close")]
                                                                 style:UIBarButtonItemStyleDone target:self action:@selector(onClose)];
   [navItem setRightBarButtonItem:barButton];
	
	roadmap_main_push_view (self);
}

- (void)dealloc
{
	[dataArray release];
	
	[super dealloc];
}



//////////////////////////////////////////////////////////
//Table view delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [(NSArray *)[dataArray objectAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	iphoneCell *cell = (iphoneCell *)[(NSArray *)[dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	int tag = [[tableView cellForRowAtIndexPath:indexPath] tag];
	
	if (id_callbacks[tag]) {
		(*id_callbacks[tag])();
	}
}



//////////////////////////////////////////////////////////
//Switch delegate
- (void) switchToggle:(id)switchView {
	static const char *yesno[2];
	if (!yesno[0]) {
		yesno[0] = "Yes";
		yesno[1] = "No";
	}
	
	UIView *view = [[switchView superview] superview];
	int tag = [view tag];
	
	switch (tag) {
      case ID_BACKLIGHT:
         roadmap_device_set_backlight([(iphoneCellSwitch *) view getState]);
			break;
		case ID_TICKER:
			if ([(iphoneCellSwitch *) view getState])
				roadmap_config_set (&RoadMapConfigShowTicker, yesno[0]);
			else
				roadmap_config_set (&RoadMapConfigShowTicker, yesno[1]);
			break;
      case ID_CLOCK_FORMAT:
			if ([(iphoneCellSwitch *) view getState])
            roadmap_config_set (&RoadMapConfigClockFormat,CLOCK_SETTINGS_24_HOUR);
			else
				roadmap_config_set (&RoadMapConfigClockFormat,CLOCK_SETTINGS_12_HOUR);
			break;
      case ID_SUGGEST_ROUTES:
			if ([(iphoneCellSwitch *) view getState])
            roadmap_alternative_routes_set_suggest_routes(TRUE);
			else
				roadmap_alternative_routes_set_suggest_routes(FALSE);
			break;
      case ID_REDIRECT_SPEAKER:
			if ([(iphoneCellSwitch *) view getState])
            roadmap_sound_set_route_to_speaker(TRUE);
			else
				roadmap_sound_set_route_to_speaker(FALSE);
			break;
      default:
			break;
	}
}

//////////////////////////////////////////////////////////
//Segmented ctrk delegate
- (void) segmentToggle:(id)segmentView {
	iphoneCellSelect *view = (iphoneCellSelect*)[[segmentView superview] superview];
	int tag = [view tag];
	
	switch (tag) {
		case ID_UNIT:
			if ([view getItem] == 0) {
				roadmap_config_set (&RoadMapConfigGeneralUserUnit,"metric");
				roadmap_math_use_metric();
			}
			else{
				roadmap_config_set (&RoadMapConfigGeneralUserUnit,"imperial");
				roadmap_math_use_imperial();
			}
			roadmap_config_save(TRUE);
			break;
		default:
			break;
	}
}

@end
