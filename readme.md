# Emacs major mode for Salesforce Task capture

A way to capture Salesforce Tasks without leaving Emacs. Search accounts, opportunities and contacts using ```sfdx``` cli tooling underneath. Enter task details and submit. Re-use previous entries as a template.

Disclaimers: my first Emacs major mode. No tests. Manually tested with Emacs 27.2. on MacOS 11.5.

## Prerequisites
Use ``brew install sfdx``` or like.

Or download and install the sfdx CLI: https://developer.salesforce.com/tools/sfdxcli

### Initiate a new project:

```
cd ~ &&  sfdx force:project:create -n salesforce
```

Creates ~/salesforce directory.

### Authenticate via the web page which pops up

```
cd ~/salesforce
sfdx force:auth:web:login --instanceurl https://xxx.salesforce.com --setalias testforce
```


### Configure sfdx

```
cd ~/salesforce
sfdx config:set defaultusername=testforce
```

## Quick start

![Screencast](images/basic-overview.svg "Screencast")

## Usage

### Starting
Open ```salesforce-task-mode.el``` in Emacs.

Run ```M-x eval-buffer``` to enter the mode.

### Login using ... Login button

This will open up your default browser, do the login chores using it.

### Select account to be used

Account is a mandatory information for task. You can search for _everything_ or narrow it down by entering text to account search field.

### Select opportunity to be used (Optional)

This information is not mandatory though, if left out, task will be attached to count.

### Select contact (Optional)

Currently only one contact can be selected.

### Fill in other details and activate "Submit form"

This will call sfdx cli and store the data in SFDC. You will have link to that entry visible on the bottom of the screen. You can refresh the view by selecting "Reset Form", you last entry will be the first in "Previous entries".

## Configuration

Configuration follows Emacs "Easy Customization Interface" so you can customize things easily:

```M-x customize-group RET salesforce-task-configuration```

You probably have to tweak at least

```Salesforce Task Sfdc Url```, the format is like "https://d09000009gcjleai-dev-ed.my.salesforce.com"

## Usability tweaks

All entries are stored on you local disk, see ```M-x describe-variable RET salesforce-task-history-file```for the location of the file. From entries previous accounts list is populated for autofill, same for previous opportunities. Also used contacts are parsed from the file and obviously previous entries.

Previous entries serve for two purposes: they have the link toward sfdc web ui for the entry and also they have the "Copy me" button which copies entry as a template.

### Tweaks left out

There is an Red Hat internal version containing Red Hat specific SFDC fields. If you are a Red Hatter, reach out to me to find out where that is located.

There are also easy ways to add filters to fields. Red Hat internal version has filtering for renewal opportunities and also accounts are filtered by country. These are left out for brevity.

# License

MIT

# Contributions

are welcomed :)

# Thanks

Fellow Red Hat Solution Architects Magnus Glantz and Ilkka Tengvall for creating Python wrapper for SFDX, got this idea from that VIM demo :-)
