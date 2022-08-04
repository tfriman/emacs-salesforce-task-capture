;;; -*- lexical-binding: t -*-
;; salesforce-task-mode.el -- Add pre-sales task entries using sfdx cli tool. See https://github.com/tfriman/emacs-salesforce-task-capture for instructions.

(require 'subr-x)
(require 'widget)
(require 'seq)
(eval-when-compile
  (require 'wid-edit))
(require 'org)

(defvar *state* (make-hash-table :test 'equal))

(defgroup salesforce-task-configuration nil "Salesforce Task Capture Mode Configurations." )

(defcustom salesforce-task-sfdc-url "https://d09000009gcjleai-dev-ed.my.salesforce.com/"
  "Url with trailing slash to contact to get SFDC connection."
  :group 'salesforce-task-configuration
  :type '(string))

(defcustom salesforce-task-sfdx-alias "testforce"
  "Target alias for SFDX connection."
  :group 'salesforce-task-configuration
  :type '(string))

(defcustom salesforce-task-account-history-size 8
  "How many past accounts should be listed in UI"
  :group 'salesforce-task-configuration
  :type '(integer))

(defcustom salesforce-task-opportunity-history-size 8
  "How many past opportunities should be listed in UI"
  :group 'salesforce-task-configuration
  :type '(integer))

(defcustom salesforce-task-history-file "~/.emacs.d/salesforce-refactored.sexp"
  "path to file to be used to store entries"
  :group 'salesforce-task-configuration
  :type '(string))

(defun salesforce-sexp-create-file ()
  "Create `history-file' if it doesn't already exist."
  (let ((history-file salesforce-task-history-file))
    (unless (file-exists-p history-file)
      (with-current-buffer (find-file-noselect history-file)
	(write-file history-file)))))

(defvar widget-account-search-field)
(defvar widget-show-account)
(defvar widget-show-opportunity)
(defvar widget-show-date)
(defvar widget-show-contact)

(defun calendar-get-date ()
  (interactive)
  (let*((date (calendar-read-date))
	(date-string (format-time-string "%Y-%m-%d\n" date)))
    date-string))

(defun widget-set-field-and-deactivate (widget-id newvalue)
  "Set value read-only"
  (interactive)
  (widget-apply widget-id :activate)
  (widget-value-set widget-id newvalue)
  (widget-apply widget-id :deactivate))

(defun p-field-widget (fieldkey displayname size)
  "Create std field"
  (widget-create 'editable-field
		 :size size
		 :format (concat displayname ": %v")
		 :value (gethash fieldkey *state* "")
		 :notify (lambda (widget &rest ignore)
			   (puthash fieldkey (widget-value widget) *state*))))

(defun deactive-field (fieldkey displayname size)
  "Create deactive field"
  (widget-create 'editable-field
		 :size size
		 :format (concat displayname ": %v")
		 :value (gethash fieldkey *state* "")))

(defun lf () "Insert lf" (widget-insert "\n"))

(defun button (text notifyfn &rest notaborder)
  "Creates button"
  (if notaborder
      (widget-create 'push-button
		     :notify notifyfn
		     :tab-order -1
		     :button-prefix ""
		     :button-suffix ""
		     :tag text)
    (widget-create 'push-button
		   :notify notifyfn
		   :button-prefix ""
		   :button-suffix ""
		   text)))

(defun init-state ()
  "Init state with sane variables"
  (salesforce-sexp-create-file)

  (clrhash *state*)

  (puthash 'account "" *state*)
  (puthash 'accountsearch "" *state*)
  (puthash 'opportunity "" *state*)
  (puthash 'contact "" *state*)
  (puthash 'contactid "" *state*)
  (puthash 'subject "TODO" *state*)
  (puthash 'status "Completed" *state*)
  (puthash 'priority "Normal" *state*)
  (puthash 'date (format-time-string "%Y-%m-%d") *state*)
  (puthash 'text "" *state*))

(defun salesforce-capture-form (&optional noinit)
  "Shows the capture form"
  (interactive)
  (switch-to-buffer "*SALESFORCE*")
  (kill-all-local-variables)
  (let ((inhibit-read-only t))
    (erase-buffer))

  (remove-overlays)
  (unless noinit (init-state))

  (widget-insert "Capture yer task here! ")
  (button "Login to SFDC" (lambda (&rest ignore) (sfdx-login)))
  (lf)
  (widget-insert "Configure stuff: \"M-x customize-group RET salesforce-task-configuration\"")
  (lf)
  (lf)

  (widget-insert "Previous accounts used:")
  (lf)
  (dolist (e (seq-take
	      (seq-uniq
	       (mapcar (lambda (x)
			 (gethash 'account x "default"))
		       (read-file salesforce-task-history-file)))
	      salesforce-task-account-history-size))
    (button (concat "" (all-but-first-word e))
	    (lambda (&rest ignore)
	      (set-account e))
	    t)
    (lf))
  (lf)

  (widget-insert "Previous opportunities used:")
  (lf)
  (dolist (e (seq-take
	      (seq-uniq
	       (read-file salesforce-task-history-file)
	       (lambda (a b)
		 (equal (gethash 'opportunity a) (gethash 'opportunity b))))
	      salesforce-task-opportunity-history-size))
    (button (concat ""
		    (all-but-first-word (gethash 'opportunity e "default"))
		    " Account:"
		    (all-but-first-word (gethash 'account e "default")))
	    (lambda (&rest ignore)
	      (set-account (gethash 'account e "nil"))
	      (set-opportunity (gethash 'opportunity e "nil"))))
    (lf))
  (lf)

  (setq widget-account-search-field (p-field-widget 'accountsearch "Account search" 40))
  (lf)

  (button "Search accounts" (lambda (&rest ignore)
			      (message "Searching accounts")
			      (let ((account (accountjson-to-prompt
					      (sfdx-get-account-by-string (widget-value widget-account-search-field)))))
				(set-account account)
				)))
  (lf)

  (setq widget-show-account (deactive-field 'account "Selected account" 80))
  (lf)

  (button "Select opportunity" (lambda (&rest ignore)
				 (let* ((accountid (get-first-word (gethash 'account *state*)))
					(oppo (prompt-opportunity accountid)))
				   (puthash 'opportunity oppo *state*)
				   (widget-set-field-and-deactivate widget-show-opportunity oppo))))
  (lf)

  (setq widget-show-opportunity (deactive-field 'opportunity "Selected opportunity" 80))
  (lf)
  (button "Search contacts" (lambda (&rest ignore)
			      (let ((contact
				     (sfdx-search-contact
				      (get-first-word (gethash 'account *state*)))))
				(puthash 'contact contact *state*)
				(puthash 'contactid (get-first-word contact) *state*)
				(widget-set-field-and-deactivate widget-show-contact contact)
				)))
  (widget-insert " ")
  (button "Previous contacts" (lambda (&rest ignore)
				(let* ((accountid (get-first-word (gethash 'account *state*)))
				       (contact (prompt-from-choices "Select contact:"
								     (gethash accountid (load-contacts) (list)))))
				  (puthash 'contact contact *state*)
				  (puthash 'contactid (get-first-word contact) *state*)
				  (widget-set-field-and-deactivate widget-show-contact contact)
				  )))
  (lf)

  (setq widget-show-contact (deactive-field 'contact "Selected contact" 80))
  (lf)

  (p-field-widget 'subject "Subject" 50)
  (lf)

  (p-field-widget 'status "Status" 20)
  (lf)

  (p-field-widget 'priority "Priority" 20)
  (lf)

  (button "Select date" (lambda (&rest ignore)
			  (let ((date (org-read-date)))
			    (puthash 'date date *state*)
			    (widget-set-field-and-deactivate widget-show-date date))))
  (setq widget-show-date (deactive-field 'date " " 12))
  (lf)

  (widget-create 'text
		 :size 80
		 :format  "Description: %v"
		 :value (gethash 'description *state* "")
		 :notify (lambda (widget &rest ignore)
			   (puthash 'description (widget-value widget) *state*)))
  (lf)
  (lf)

  (button "Send Form" (lambda (&rest ignore)
			(sfdx-create-task)))

  (button "Reset Form" (lambda (&rest ignore)
			 (clrhash *state*)
			 (salesforce-task-capture)))

  (button "Print state" (lambda (&rest ignore)
			  (message "hash keys %S and vals: %S" (hash-table-keys *state*) (hash-table-values *state*))))

  (lf)
  (widget-insert "Previous entries")
  (lf)
  (dolist (e (read-file salesforce-task-history-file))
    (widget-create 'url-link
		   :button-prefix (concat (gethash 'date e "") " ")
		   :button-suffix ""
		   :format (concat "%[" (gethash 'subject e "default") "%]")
		   :button-face 'info-xref
		   (concat salesforce-task-sfdc-url (gethash 'sfdcid e)))
    (button "Copy me" (lambda (&rest ignore)
			(clrhash *state*)
			(setq *state* e)
			(puthash 'date (format-time-string "%Y-%m-%d") *state*)
			(remhash 'sfdcid *state*)
			(remhash 'created *state*)
			(salesforce-task-capture t)))
    (lf))
  (use-local-map widget-keymap)
  (widget-setup))

(defun set-account (account)
  "Sets account"
  (puthash 'account account *state*)
  (widget-set-field-and-deactivate widget-show-account account))

(defun set-opportunity (opportunity)
  "Sets opportunity"
  (puthash 'opportunity opportunity *state*)
  (widget-set-field-and-deactivate widget-show-opportunity opportunity))

(defun all-but-first-word (inputstring)
  "Drop first word"
  (string-join (cdr (split-string inputstring " ")) " "))

(defun get-first-word (inputstring)
  "Get the first word of the string before space"
  (car (split-string inputstring " ")))

(defun prompt-from-choices (prompt choices)
  "Prompt one of the choices"
  (interactive)
  (ido-completing-read prompt choices))

(defun prompt-opportunity (accountid)
  "Get oppos for chosen account and store the selected one"
  (let* ((oppos (sfdx-get-oppos-by-accountid accountid))
	 (oppstrings (mapcar
		      (lambda (a) (concat
				   (gethash "Id" a)
				   " "
				   (gethash "Name" a)))
		      oppos))
	 (chosenopp (prompt-from-choices "Select opportunity:" oppstrings)))
    chosenopp))

(defun gv-or (k fallback)
  "Helper for getting stuff from state map, gets another key if first is nil"
  (let ((kres (gethash k *state*)))
    (if (equal kres "")
	(gethash fallback *state*)
      kres)))

(defun gv (k) "Helper for getting stuff from state map" (gethash k *state*))

(defun contactjson-to-prompt (contacts)
  "json contacts are prompted, contact id is returned"
  (let ((contactstrings (mapcar
			 (lambda (a) (concat
				      (gethash "Id" a)
				      " "
				      (gethash "Name" a)))
			 contacts)))
    (prompt-from-choices "Select contact:" contactstrings)))

(defun sfdx-search-contact (accountid)
  "Searches account contacts, returns seq of them"
  (let* ((json
	  (shell-command-to-string
	   (concat "sfdx force:data:soql:query --targetusername=" salesforce-task-sfdx-alias " -q \"SELECT Id, Name FROM Contact WHERE AccountId = '"  accountid "'\" --resultformat=json")
	   ))
	 (contacts (gethash "records"
			    (gethash "result"
				     (json-parse-string json)))))
    (contactjson-to-prompt contacts)))

(defun sfdx-create-task ()
  "Creates a task based on task map"
  (print *state*)
  (let* ((create-string
	  (concat "sfdx force:data:record:create --targetusername " salesforce-task-sfdx-alias
		  " --sobjecttype "
		  " Task -v \"Subject='" (gv 'subject) "' "
		  " ActivityDate=" (gv 'date) " "
		  " Status='" (gv 'status) "' "
		  " Priority='" (gv 'priority) "' "
		  " WhoId=" (gv 'contactid) " "
		  " WhatId=" (get-first-word (gv-or 'opportunity 'account)) " "
		  " Description='" (gv 'description) "' "
		  " recordTypeId=012000000000000AAA"
		  "\""
		  " --json"))
	 (ignore (message "XXX %S" create-string))
	 (response (shell-command-to-string create-string))
	 (jsonresponse (json-parse-string response))
	 (statuscode (gethash "status" jsonresponse)))
    (if (= statuscode 0)
	(let* ((result (gethash "result" jsonresponse))
	       (success (gethash "success" result))
	       (sfdcid (gethash "id" result)))
	  (if (equal t success)
	      (progn
		(puthash 'sfdcid sfdcid *state*)
		(puthash 'created (format-time-string "%Y-%m-%d") *state*)
		(insert-hash-to-log *state*)
		(message "Task added with id %s with subject %s" sfdcid (gv 'subject)))
	    (progn
	      (message "Store was not success! %s" response)
	      (message "Tried with %s" create-string))))
      (progn
	(message "Store FAILED! %s" response)
	(message "Tried with %s" create-string)))))

(defun sfdx-login ()
  (message "login result: %s" (shell-command-to-string (concat "sfdx force:auth:web:login --instanceurl " salesforce-task-sfdc-url " --setalias " salesforce-task-sfdx-alias))))

(defun sfdx-get-oppos-by-accountid (accountid)
  "Search account's opportunities"
  (gethash "records"
	   (gethash "result"
		    (json-parse-string
		     (shell-command-to-string
		      (concat "sfdx force:data:soql:query --targetusername=" salesforce-task-sfdx-alias " -q \"SELECT Id, Name, StageName, AccountId FROM Opportunity WHERE AccountId = \'" accountid "\' AND (NOT StageName LIKE \'Closed%\') AND (NOT StageName LIKE \'Rejected%\')\" --resultformat=json"))))))

(defun accountjson-to-prompt (accounts)
  "json accounts are prompted, account id is returned"
  (let ((accstrings (mapcar (lambda (a) (concat
					 (gethash "Id" a)
					 " "
					 (gethash "Name" a)))
			    accounts)))
    (prompt-from-choices "Select account:" accstrings)))

(defun sfdx-get-account-by-string (accountstring)
  "Search accounts"
  (let* ((response (shell-command-to-string
		    (concat "sfdx force:data:soql:query --targetusername=" salesforce-task-sfdx-alias " -q \"SELECT Id, Name FROM Account WHERE Name LIKE '%" accountstring "%'\" --resultformat=json")))
	 ;;(ignore (message "debug Got accounts by string: %S" response))
	 (jsonres (json-parse-string response))
	 ;;(ignorejson (message "jsonres %S" jsonres))
	 (tmpresult (gethash "result" jsonres))
	 ;;(ignoretmp (message "Got tmp result: %S" tmpresult))
	 (result (gethash "records" tmpresult))
	 ;;(ignore2 (message "Got accs result: %S" result))
	 )
    ;; TODO clean this up
    result))

(defun read-file (filepath)
  "Reads file containing sexps and returns them as a list"
  (with-temp-buffer
    (save-excursion
      (insert "(\n")
      (insert-file-contents filepath)
      (goto-char (point-max))
      (insert "\n)\n"))
    (read (current-buffer))))

(defun salesforce-sexp-open-log ()
  "Open `history-file' in another window and go to the beginning."
  (find-file-other-window salesforce-task-history-file)
  (goto-char (point-min)))

(defun insert-hash-to-log (entry)
  "Insert entry to the beginning of the file"
  (let ((log (salesforce-sexp-open-log)))
    (prin1 entry (current-buffer))
    (insert "\n")
    (save-buffer)
    (kill-this-buffer)
    (if (not (one-window-p))
	(delete-window))))

(defun load-contacts ()
  "Loads last contacts as map with key to account and list to contacts"
  (let ((contact-map (make-hash-table :test 'equal)))
    (dolist (e (read-file salesforce-task-history-file))
      (message "load-contacts processing %S" e)
      (let* ((accountid (get-first-word (gethash 'account e)))
	     (contact (gethash 'contact e ""))
	     (mapentry (gethash accountid contact-map (list))))
	(when (not (string-empty-p contact))
	  (puthash accountid (cons contact mapentry) contact-map))))
    contact-map))

(defun salesforce-task-capture (&optional nonit)
  "Start it!"
  (salesforce-capture-form nonit)
  (goto-char (point-min)))

(salesforce-task-capture)
