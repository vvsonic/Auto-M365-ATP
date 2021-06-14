<#
#################################################
## Advanced Threat Protection Configuration Master v1.2 (Updated and Tested 6/14/2021)
#################################################

This script automates a lot of the set up process of M365 ATP and Exchange Online.
This script is safe to run after communicating ATP to the client and should have none, if any end-user disruption.
This script is now non-destructive and will ingest all custom whitelist and blacklist options from current or previously configured default profiles.


!! Make sure to install each module and check all prerequisites + Global Variables !! 

    Connect to Exchange Online via PowerShell using MFA (Connect-ExchangeOnline)
    https://docs.microsoft.com/en-us/powershell/exchange/exchange-online/connect-to-exchange-online-powershell/mfa-connect-to-exchange-online-powershell?view=exchange-ps

    Connect to Security and Compliance center via PowerShell using Modern Authentication (Connect-IPPSSession)
    https://docs.microsoft.com/en-us/powershell/exchange/connect-to-scc-powershell?view=exchange-ps

Created By : Alex Ivantsov
Email : alex@ivantsov.tech
Company : Umbrella IT Solutions

#>

#################################################
## Pre-Reqs & Variables
#################################################

    ## Global Variables

        # Domains and Senders to whitelist by default from ALL POLICIES. This includes Phishing, Anti-Spam, Etc.. Comma seperated.

            $ExcludedDomains = "intuit.com", "Umbrellaitgroup.com" | Select-Object -Unique # QB Online has been getting popped for phishing lately. Highly reccomended to include Intuit.

            $ExcludedSenders = "connect@e.connect.intuit.com", "info@umbrellaitgroup.com", "security@umbrellaitgroup.com", "advanced-threat-protection@protection.outlook.com" | Select-Object -Unique

        # File types to be blacklisted in the Anti-Malware Policy. Additional filetypes here to blacklist seperated by comma with quotes

            $NewFileTypeBlacklist = "ade", "adp", "app", "application", "arx", "avb", "bas", "bat", "chm", "class", "cmd", "cnv", "com", "cpl", "crt", "dll", "docm", "drv", "exe", "fxp", "gadget", "gms", "hlp", "hta", "inf", "ink", "ins", "isp", "jar", "job", "js", "jse", "lnk", "mda", "mdb", "mde", "mdt", "mdw", "mdz", "mpd", "msc", "msi", "msp", "mst", "nlm", "ocx", "ops", "ovl", "paf", "pcd", "pif", "prf", "prg", "ps1", "psd1", "psm", "psm1", "reg", "scf", "scr", "sct", "shb", "shs", "sys", "tlb", "tsp", "url", "vb", "vbe", "vbs", "vdl", "vxd", "wbt", "wiz", "wsc", "wsf", "wsh" | Select-Object -Unique

        # Your MSP's information for alerting and support info for end-user notifications
                
            $MSPAlertAddress = "Security@umbrellaitgroup.com"
                        
            $MSPSupportMail = "Support@Umbrellaitgroup.com"

            $MSPSupportInfo = "Umbrella IT Group (904) 930-4261"

        # Other Variables

            $CusAdminAddress = Read-Host "Enter the Customer's ADMIN EMAIL ADDRESS. This is where you will recieve alerts, notifications and set up admin access to all mailboxes. MUST BE AN INTERNAL ADMIN ADDRESS"
            $MessageColor = "Green"
            $AssesmentColor = "Yellow"
            # $AllowedForwardingGroup =  Read-Host "Enter the GUID of the SECURITY GROUP ** IN " QUOTES ** which will allow forwarding to external receipients. (MUST BE ACTIVE IN AAD)"
            # Allowed Forwarding by security groups doesn't work well in practice due to Microsoft. No fix available yet.


#################################################
## Script Start
#################################################

    $Answer = Read-Host "Have you connected all the required PowerShell CMDlets? Y/N "
    if ($Answer -eq 'n' -or $Answer -eq 'no') {

        ## Connecting Modules

        Write-Host -foregroundcolor $AssesmentColor "Connecting Modules (ExchangeOnline, MSOL, AzureAD, MSGraph) ..."

        Connect-ExchangeOnline

        Connect-IPPSSession

    }

    # Setup Forwarding and Disable Junk Folder for the Alerting Mailbox
        Write-Host -foregroundcolor $MessageColor "Seting up automatic forwarding from $CusAdminAddress > to > $MSPAlertAddress"
        Write-Host
        Write-Host
        Set-Mailbox -Identity $CusAdminAddress -DeliverToMailboxAndForward $true -ForwardingSMTPAddress $MSPAlertAddress
        Write-Host -ForegroundColor $MessageColor "Forwarding has successfully been configured for the specified mailbox."
        Write-Host
        Write-Host
        get-mailbox -Identity $CusAdminAddress | Format-List Username, ForwardingSMTPAddress, DeliverToMailboxandForward
            
        Write-Host -foregroundcolor $MessageColor "Disabling Junk Mailbox on $CusAdminAddress"
                
        Set-MailboxJunkEmailConfiguration -Identity $CusAdminAddress -Enabled $false -ErrorAction SilentlyContinue
        Write-Host
        Write-Host
        Write-Host -ForegroundColor $MessageColor "JunkMailbox has successfully been disabled, this way you will receive all mail from the inbox regardless of mailbox junk policy."


#################################################
## Anti-Malware
#################################################
    Write-Host
    Write-Host
    Write-Host -foregroundcolor $MessageColor "Configuring the default Anti-Malware Policy with [v1.2] settings..."

    ## Default Malware Blacklist
    ## Grab current default File Blacklist and add new entries...
        $CurrentTypeBlacklist = Get-MalwareFilterPolicy -Identity Default | Select-Object -Expand FileTypes
        $FileTypeBlacklist = $CurrentTypeBlacklist + $NewFileTypeBlacklist | Select-Object -Unique

        Write-Host -foregroundcolor $MessageColor "Configuring Anti-Malware Policy [v1.2]"
        Write-Host
        Write-Host
        Write-Host -ForegroundColor $AssesmentColor "The Attachment Blacklist contains the following entries. To add more file types, Ctrl-C to cancel and edit the script under the FileTypeBlacklist Variable" 
        Write-Host -ForegroundColor Red $FileTypeBlacklist
        Write-Host
        Write-Host
        Write-Host -foregroundcolor $AssesmentColor "In order to fully set up the default malware policy, you must disable all other rules and policies."

        Get-MalwareFilterPolicy | Remove-MalwareFilterPolicy
        Get-MalwareFilterRule | Remove-MalwareFilterRule

    Write-Host -foregroundcolor $MessageColor "Setting up the Default Anti-Malware Policy [v1.2]"

        $MalwarePolicyParam = @{
            'AdminDisplayName'                       = "AntiMalware Policy [v1.2] Imported via PS";
            'Action'                                 = 'DeleteAttachmentAndUseCustomAlert';
            'EnableFileFilter'                       = $true;
            'FileTypes'                              = $FileTypeBlacklist;
            'ZapEnabled'                             = $true;

            'CustomFromName'                         = "ATP Antimalware Scanner";
            'CustomAlertText'                        = "You have received a message that was found to contain malware and protective actions have been automatically taken. If you beleive this is a false positive, please forward this message to $MSPSupportMail ";
            'CustomNotifications'                    = $true;
            'CustomFromAddress'                      = $CusAdminAddress;
            'InternalSenderAdminAddress'             = $CusAdminAddress;
            'EnableInternalSenderNotifications'      = $true;
            'EnableInternalSenderAdminNotifications' = $true;
            'CustomInternalSubject'                  = "Malware Detected in your Message"
            'CustomInternalBody'                     = "A message sent by you was found to potentially contain malware. Your message was NOT delivered and protective actions have been automatically taken. Please reach out to $MSPSupportInfo immediately, and forward this message to $MSPSupportMail";

            'ExternalSenderAdminAddress'             = $CusAdminAddress;
            'EnableExternalSenderNotifications'      = $true;
            'EnableExternalSenderAdminNotifications' = $true;
            'CustomExternalSubject'                  = "Malware Detected in your Message";
            'CustomExternalBody'                     = "We received a message from you that was found to potentially contain malware. Your message was not delivered and protective actions have been automatically taken. It is recomended that you forward this message to your IT Security Department for further investigation.";
        }

        $MalwarePolicyParamAdmin = @{
            'Name'                                   = "Bypass Malware Filter (for Admin)";
            'AdminDisplayName'                       = "Bypass Malware Filter Policy/Rule for Admin";
            'CustomAlertText'                        = "Malware was received and blocked from being delivered. Review the email received in https://protection.office.com/threatreview";
            'Action'                                 = "DeleteAttachmentAndUseCustomAlertText";
            'InternalSenderAdminAddress'             = $CusAdminAddress;
            'EnableInternalSenderAdminNotifications' = $True;
            'ZapEnabled'                             = $False;
        }

        $MalwareRuleParamAdmin = @{
            'Name'                = "Bypass Malware Filter (for Admin)";
            'MalwareFilterPolicy' = "Bypass Malware Filter (for Admin)";
            'SentTo'              = $CusAdminAddress;
            'Enabled'             = $True;
        }

    Set-MalwareFilterPolicy Default @MalwarePolicyParam -MakeDefault
    New-MalwareFilterPolicy @MalwarePolicyParamAdmin
    New-MalwareFilterRule @MalwareRuleParamAdmin

    Write-Host
    Write-Host
    Write-Host -foregroundcolor $MessageColor "Anti-Malware Policy [v1.2] has been successfully set."


#################################################
## Anti-Phishing
#################################################

    # Grab all accepted Domains. (Also used in other parts of the script)
        $AcceptedDomains = Get-AcceptedDomain
        $RecipientDomains = $AcceptedDomains.DomainName

    ## Grab current default whitelisted entries and adding new entries...
        $AlreadyExcludedPhishSenders = Get-Antiphishpolicy "Office365 AntiPhish Default" | Select-Object -Expand ExcludedSenders
        $AlreadyExcludedPhishDomains = Get-Antiphishpolicy "Office365 AntiPhish Default" | Select-Object -Expand ExcludedDomains
        $WhitelistedPhishSenders = $AlreadyExcludedPhishSenders + $ExcludedSenders | Select-Object -Unique
        $WhitelistedPhishDomains = $AlreadyExcludedPhishDomains + $ExcludedDomains | Select-Object -Unique

    $items = Get-Mailbox | Select-Object DisplayName, UserPrincipalName
    $combined = $items | ForEach-Object { $_.DisplayName + ';' + $_.UserPrincipalName }
    $TargetUserstoProtect = $combined

    Write-Host
    Write-Host 
    Write-Host -foregroundcolor $MessageColor "Modifying the 'Office365 AntiPhish Default' policy with Anti-Phish Baseline Policy AntiPhish Policy [v1.2]"

        $PhishPolicyParam = @{
            'AdminDisplayName'                    = "AntiPhish Policy [v1.2] Imported via PS";
            'Enabled'                             = $true;
            'AuthenticationFailAction'            = 'MoveToJmf';
            'EnableMailboxIntelligence'           = $true;
            'EnableMailboxIntelligenceProtection' = $true;
            'EnableOrganizationDomainsProtection' = $true;
            'EnableSimilarDomainsSafetyTips'      = $true;
            'EnableSimilarUsersSafetyTips'        = $true;
            'EnableSpoofIntelligence'             = $true;
            'EnableUnauthenticatedSender'         = $true;
            'EnableUnusualCharactersSafetyTips'   = $true;
            'MailboxIntelligenceProtectionAction' = 'MoveToJmf';
            'ImpersonationProtectionState'        = 'Automatic';
            
            'EnableTargetedDomainsProtection'     = $True;
            'TargetedDomainProtectionAction'      = 'Quarantine';
            'TargetedDomainsToProtect'            = $RecipientDomains;

            'EnableTargetedUserProtection'        = $True;
            'TargetedUserProtectionAction'        = 'Quarantine';
            'TargetedUsersToProtect'              = $TargetUserstoProtect;

            'ExcludedDomains'                     = $WhitelistedPhishDomains;
            'ExcludedSenders'                     = $WhitelistedPhishSenders;
            
            'PhishThresholdLevel'                 = 2;
            ## 1: Standard: This is the default value. The severity of the action that's taken on the message depends on the degree of confidence that the message is phishing (low, medium, high, or very high confidence). For example, messages that are identified as phishing with a very high degree of confidence have the most severe actions applied, while messages that are identified as phishing with a low degree of confidence have less severe actions applied.
            ## 2: Aggressive: Messages that are identified as phishing with a high degree of confidence are treated as if they were identified with a very high degree of confidence.
            ## 3: More aggressive: Messages that are identified as phishing with a medium or high degree of confidence are treated as if they were identified with a very high degree of confidence.
            ## 4: Most aggressive: Messages that are identified as phishing with a low, medium, or high degree of confidence are treated as if they were identified with a very high degree of confidence.
        }
    Set-AntiPhishPolicy -Identity "Office365 AntiPhish Default" @PhishPolicyParam

    Write-Host
    Write-Host -foregroundcolor $AssesmentColor "Disabling all the old, non-default phishing rules and policies"

    Get-AntiPhishPolicy | Remove-AntiPhishPolicy
    Get-AntiPhishRule | Remove-AntiPhishRule

    Write-Host
    Write-Host -foregroundcolor $MessageColor "AntiPhish Policy [v1.2] has been successfully configured"


#################################################
## Anti-Spam (Hosted Content Filter)
#################################################
    Write-Host -foregroundcolor $MessageColor "Setting up the new Default Inbound Anti-Spam Policy [v1.2]"

        $HostedContentPolicyParam = @{
            'AddXHeaderValue'                      = "M365 ATP Analysis: ";
            'AdminDisplayName'                     = "Inbound Anti-Spam Policy [v1.2] configured via M365 PS Scripting Tools";
            'AllowedSenders'                       = @{add = $ExcludedSenders };
            'AllowedSenderDomains'                 = @{add = $ExcludedDomains };
            # 'BlockedSenders'                       = @{add= $BlacklistedSpamSenders};
            # 'BlockedSenderDomains'                 = @{add= $BlacklistedSpamDomains};

            'DownloadLink'                         = $false;
            'SpamAction'                           = 'MoveToJMF';
            'HighConfidenceSpamAction'             = 'quarantine';
            'PhishSpamAction'                      = 'quarantine';
            'HighConfidencePhishAction'            = 'quarantine';
            'BulkSpamAction'                       = 'MoveToJMF';
            'BulkThreshold'                        = '8';
            'QuarantineRetentionPeriod'            = 30;
            'InlineSafetyTipsEnabled'              = $true;
            'EnableEndUserSpamNotifications'       = $true;
            'EndUserSpamNotificationFrequency'     = 1;
            'EndUserSpamNotificationCustomSubject' = "Daily Email Quarantine Report";
            'RedirectToRecipients'                 = $CusAdminAddress;
            'ModifySubjectValue'                   = "PhishSpamAction,HighConfidenceSpamAction,BulkSpamAction,SpamAction";
            'SpamZapEnabled'                       = $true;
            'PhishZapEnabled'                      = $true;
            'MarkAsSpamBulkMail'                   = 'on';
            'IncreaseScoreWithImageLinks'          = 'off';
            'IncreaseScoreWithNumericIps'          = 'on';
            'IncreaseScoreWithRedirectToOtherPort' = 'on';
            'IncreaseScoreWithBizOrInfoUrls'       = 'on';
            'MarkAsSpamEmptyMessages'              = 'on';
            'MarkAsSpamJavaScriptInHtml'           = 'on';
            'MarkAsSpamFramesInHtml'               = 'off';
            'MarkAsSpamObjectTagsInHtml'           = 'off';
            'MarkAsSpamEmbedTagsInHtml'            = 'off';
            'MarkAsSpamFormTagsInHtml'             = 'off';
            'MarkAsSpamWebBugsInHtml'              = 'on';
            'MarkAsSpamSensitiveWordList'          = 'off';
            'MarkAsSpamSpfRecordHardFail'          = 'on';
            'MarkAsSpamFromAddressAuthFail'        = 'on';
            'MarkAsSpamNdrBackscatter'             = 'on';
        }
    Set-HostedContentFilterPolicy Default @HostedContentPolicyParam -MakeDefault

    Write-Host 
    Write-Host -foregroundcolor $MessageColor " Inbound Anti-Spam Policy [v1.2] is deployed and set as Default."
    Write-Host 

    $Answer2 = Read-Host "Do you want to DISABLE (not delete) custom anti-spam rules, so that only Anti-Spam Policy [v1.2] Apply? This is recommended unless you have other custom rules in use. Type Y or N and press Enter to continue"
    if ($Answer2 -eq 'y' -or $Answer2 -eq 'yes') {

        Get-HostedContentFilterRule | Disable-HostedContentFilterRule
                    
        Write-Host
        Write-Host -ForegroundColor $AssesmentColor "All custom anti-spam rules have been disabled; they have not been deleted"
        Write-Host 
        Write-Host -foregroundcolor $MessageColor " Anti-Spam Policy [v1.2] is set as Default and is the only enforcing Imbound Rule."
    }
    else {
        Write-Host 
        Write-Host -ForegroundColor $AssesmentColor "Custom rules have been left enabled. Please manually verify that the new Default Policy is being used in Protection.Office.com."
    }

    Write-Host 
    Write-Host 
    Write-Host -foregroundcolor $MessageColor "Setting up a new Inbound/Outbound & Forwarding Anti-Spam Policy for Admin & Allowed-Forwarding group"

        $OutboundPolicyForITAdmin = @{
            'Name'                          = "Allow Outbound Forwarding Policy"
            'AdminDisplayName'              = "Unrestricted Outbound Forwarding Policy from specified mailboxes (Should only be used for Admin and Service Mailboxes)";
            'AutoForwardingMode'            = "On";
            'RecipientLimitExternalPerHour' = 10000;
            'RecipientLimitInternalPerHour' = 10000;
            'RecipientLimitPerDay'          = 10000;
            'ActionWhenThresholdReached'    = 'Alert';
            'BccSuspiciousOutboundMail'     = $false
        }
        New-HostedOutboundSpamFilterPolicy @OutboundPolicyForITAdmin

        $OutboundRuleForAdmin = @{
            'Name'                           = "Allow Outbound Forwarding Rule";
            'Comments'                       = "Unrestricted Outbound Forwarding Policy from specified mailbox";
            'HostedOutboundSpamFilterPolicy' = "Allow Outbound Forwarding Policy";
            'Enabled'                        = $true;
            'From'                           = $CusAdminAddress; #Tried to make this a security group at first, but it turned out jank. Doesn't work well.
            # 'FromMemberOf' = $AllowedForwardingGroup
            'Priority'                       = 0
        }
        New-HostedOutboundSpamFilterRule @OutboundRuleForAdmin

        $AdminIndoundContentPolicyParam = @{
            'Name'                                 = "Unrestricted Content Filter Policy for Admin"
            'AdminDisplayName'                     = "Inbound ADMIN Policy [v1.2] configured via M365 PS Scripting Tools";
            'AddXHeaderValue'                      = "Unrestricted-Admin-Mail: ";
            'RedirectToRecipients'                 = $MSPAlertAddress;
            'DownloadLink'                         = $false;
            'SpamAction'                           = 'AddXHeader';
            'HighConfidenceSpamAction'             = 'AddXHeader';
            'PhishSpamAction'                      = 'AddXHeader';
            'HighConfidencePhishAction'            = 'Redirect';
            'BulkSpamAction'                       = 'AddXHeader';
            'InlineSafetyTipsEnabled'              = $true;
            'ModifySubjectValue'                   = "PhishSpamAction,HighConfidenceSpamAction,BulkSpamAction,SpamAction";
            'SpamZapEnabled'                       = $false;
            'PhishZapEnabled'                      = $false;
            'QuarantineRetentionPeriod'            = 30;

            'MarkAsSpamBulkMail'                   = 'off';
            'IncreaseScoreWithImageLinks'          = 'off';
            'IncreaseScoreWithNumericIps'          = 'off';
            'IncreaseScoreWithRedirectToOtherPort' = 'off';
            'IncreaseScoreWithBizOrInfoUrls'       = 'off';
            'MarkAsSpamEmptyMessages'              = 'off';
            'MarkAsSpamJavaScriptInHtml'           = 'off';
            'MarkAsSpamFramesInHtml'               = 'off';
            'MarkAsSpamObjectTagsInHtml'           = 'off';
            'MarkAsSpamEmbedTagsInHtml'            = 'off';
            'MarkAsSpamFormTagsInHtml'             = 'off';
            'MarkAsSpamWebBugsInHtml'              = 'off';
            'MarkAsSpamSensitiveWordList'          = 'off';
            'MarkAsSpamSpfRecordHardFail'          = 'off';
            'MarkAsSpamFromAddressAuthFail'        = 'off';
            'MarkAsSpamNdrBackscatter'             = 'off';
        }
        New-HostedContentFilterPolicy @AdminIndoundContentPolicyParam

        $AdminIndoundContentRuleParam = @{
            'Name'                      = "Unrestricted Content Filter Rule for Admin"
            'Comments'                  = "Inbound ADMIN Rule [v1.2] configured via M365 PS Scripting Tools";
            'HostedContentFilterPolicy' = "Unrestricted Content Filter Policy for Admin";
            'Enabled'                   = $true;
            'Confirm'                   = $false;
            'Priority'                  = "0";
            'SentTo'                    = $CusAdminAddress
        }
        New-HostedContentFilterRule @AdminIndoundContentRuleParam

    Write-Host 
    Write-Host -foregroundcolor $MessageColor "Successfully Set up Policy + Rule for Admin"

        $OutboundPolicyDefault = @{
            'AdminDisplayName'                          = "Outbound Anti-Spam Policy [v1.2] configured via M365 PS Scripting Tools";
            'AutoForwardingMode'                        = "Off";
            'RecipientLimitExternalPerHour'             = 100;
            'RecipientLimitInternalPerHour'             = 100;
            'RecipientLimitPerDay'                      = 500;
            'ActionWhenThresholdReached'                = 'Alert';
            'BccSuspiciousOutboundMail'                 = $true;
            'BccSuspiciousOutboundAdditionalRecipients' = $CusAdminAddress
        }
        Set-HostedOutboundSpamFilterPolicy Default @OutboundPolicyDefault

    Write-Host    
    Write-Host
    Write-Host -ForegroundColor $MessageColor "The admin forwarding and default outbound spam filter have been set to Outbound Anti-Spam Policy [v1.2]"
   

#################################################
## Safe-Attachments
#################################################
    Write-Host -foregroundcolor $MessageColor "Creating the new  Safe Attachments [v1.2] Policy..."
    Write-Host	
    Write-Host -foregroundcolor $AssesmentColor "In order to properly set up the new policies, you must remove the old ones."

    Get-SafeAttachmentPolicy | Remove-SafeAttachmentPolicy
    Get-SafeAttachmentRule | Disable-SafeAttachmentRule

        $SafeAttachmentPolicyParam = @{
            'Name'             = "Safe Attachments Policy [v1.2]";
            'AdminDisplayName' = "Safe Attachments Policy [v1.2] configured via M365 PS Scripting Tools";
            'Action'           = "DynamicDelivery";
            ## Action options = Block | Replace | Allow | DynamicDelivery
            'Redirect'         = $true;
            'RedirectAddress'  = $CusAdminAddress;
            'ActionOnError'    = $true;
            'Enable'           = $true
            #'RecommendedPolicyType' = No documentation available
        }
        New-SafeAttachmentPolicy @SafeAttachmentPolicyParam

        $SafeAttachRuleParam = @{
            'Name'                 = "Safe Attachments Rule [v1.2]";
            'SafeAttachmentPolicy' = "Safe Attachments Policy [v1.2]";
            'Comments'             = "Safe Attachments Rule [v1.2] configured via M365 PS Scripting Tools";
            'RecipientDomainIs'    = $RecipientDomains;
            'ExceptIfSentTo'       = $CusAdminAddress;
            #   'ExceptIfRecipientDomainIs' = $ExcludedDomains;
            'Enabled'              = $true;
            'Priority'             = 1
        }
        New-SafeAttachmentRule @SafeAttachRuleParam

        $SafeAttachmentPolicyParamAdmin = @{
            'Name'             = "Safe Attachments Bypass for Admin PS";
            'AdminDisplayName' = "Bypass Rule for Admin/Alerts Mailbox";
            'Action'           = "Allow";
            'Redirect'         = $false;
            'ActionOnError'    = $false;
            'Enable'           = $false
        }
        New-SafeAttachmentPolicy @SafeAttachmentPolicyParamAdmin

        $SafeAttachmentRuleParamAdmin = @{
            'Name'                 = "Safe Attachments Bypass for Admin PS";
            'SafeAttachmentPolicy' = "Safe Attachments Bypass for Admin PS";
            'SentTo'               = $CusAdminAddress;
            'Enabled'              = $true
            'Priority'             = 0
        }
        New-SafeAttachmentRule @SafeAttachmentRuleParamAdmin

    Write-Host 
    Write-Host -foregroundcolor $MessageColor "The new  Safe Attachments Policies and rules [v1.2] are deployed."
    Write-Host 


#################################################
## Safe-Links
#################################################
    Write-Host -foregroundcolor $MessageColor "Creating new policies for Safe-Links [v1.2]"
    Write-Host
    Write-Host
    Write-Host -foregroundcolor $AssesmentColor "In order to properly set up the new policies, you must remove the old ones."

    Get-SafeLinksPolicy | Remove-SafeLinksPolicy
    Get-SafeLinksRule | Remove-SafeLinksRule

        $AtpSafeLinksO365Param = @{
            'EnableATPForSPOTeamsODB'       = $true;
            'EnableSafeLinksForO365Clients' = $true;
            'EnableSafeDocs'                = $true;
            'AllowSafeDocsOpen'             = $false;
            'TrackClicks'                   = $true;
            'AllowClickThrough'             = $false
        }

    Set-AtpPolicyForO365 @AtpSafeLinksO365Param

    write-host -foregroundcolor $MessageColor "Global Default Safe Links policy has been set."
    Write-Host
    Write-Host -foregroundcolor $MessageColor "Creating new policy: ' Safe Links Policy [v1.2]'"

        $SafeLinksPolicyParamAdmin = @{
            'IsEnabled'                  = $false;
            'Name'                       = "Bypass Safelinks for Admin";
            'AdminDisplayName'           = "Bypass Safe Links Policy [v1.2] configured via M365 PS Scripting Tools";
            'ScanUrls'                   = $false;
            'DeliverMessageAfterScan'    = $False;
            'EnableForInternalSenders'   = $False;
            'DoNotTrackUserClicks'       = $false;
            'DoNotAllowClickThrough'     = $False;
            'EnableOrganizationBranding' = $False;
        }
        New-SafeLinksPolicy @SafeLinksPolicyParamAdmin

        $SafeLinksRuleParamAdmin = @{
            'Name'            = "Bypass Safelinks for Admin";
            'Comments'        = "Bypass Safe Links Policy [v1.2] configured via M365 PS Scripting Tools";
            'SafeLinksPolicy' = "Bypass Safelinks for Admin";
            'SentTo'          = $CusAdminAddress;
            'Enabled'         = $true;
            'Priority'        = 0
        }
        New-SafeLinksRule @SafeLinksRuleParamAdmin

        $SafeLinksPolicyParam = @{
            'IsEnabled'                  = $true;
            'Name'                       = "Safe Links Policy [v1.2]";
            'AdminDisplayName'           = "Safe Links Policy [v1.2] configured via M365 PS Scripting Tools";
            #    'EnableSafeLinksForTeams' = $true; Only a part of the TAP Program - License required
            'ScanUrls'                   = $true;
            'DeliverMessageAfterScan'    = $true;
            'EnableForInternalSenders'   = $true;
            'DoNotTrackUserClicks'       = $false;
            'DoNotAllowClickThrough'     = $true;
            'EnableOrganizationBranding' = $true;
            #'RecommendedPolicyType' = No documentation available
            #'UseTranslatedNotificationText' = No documentation available
        }
        New-SafeLinksPolicy @SafeLinksPolicyParam 

        $SafeLinksRuleParam = @{
            'Name'              = "Safe Links Rule [v1.2]";
            'Comments'          = "Safe Links Rule [v1.2] configured via M365 PS Scripting Tools";
            'SafeLinksPolicy'   = "Safe Links Policy [v1.2]";
            'RecipientDomainIs' = $RecipientDomains;
            'ExceptIfSentTo'    = $CusAdminAddress;
            #  'ExceptIfRecipientDomainIs' = $ExcludedDomains;
            'Enabled'           = $true;
            'Priority'          = 1
        }
        New-SafeLinksRule @SafeLinksRuleParam

    Write-Host -foregroundcolor $MessageColor "Safe Links Global Defaults, Policies and Rules [v1.2] has been successfully configured"

    Write-Host
    Write-Host
    Write-Host -ForegroundColor $MessageColor "This concludes the script for [v1.2] ATP Master Configs"