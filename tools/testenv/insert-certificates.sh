#!/bin/bash

echo "MySQL: inserting test data (root/signer/vault/scep certificates)"

#
# Files for /etc
#
BASE="/etc/openxpki/ssl/ca-one/";
if [ ! -d "$BASE" ]; then mkdir -p "$BASE"; fi

if [ -e "$BASE/ca-root-1.crt" ] ||  [ -e "$BASE/ca-root-1.pem" ]; then
   echo "found exisiting ca files in directory, please remove all files!"
   exit 1
fi

cp $(dirname $0)/certificates/* $BASE/

#
# Database entries
#
DBPASS=""
test ! -z "$OXI_TEST_DB_MYSQL_DBPASSWORD" && DBPASS="-p$OXI_TEST_DB_MYSQL_DBPASSWORD" || true

cat <<'__SQL' | mysql -h $OXI_TEST_DB_MYSQL_DBHOST -P $OXI_TEST_DB_MYSQL_DBPORT -u$OXI_TEST_DB_MYSQL_DBUSER $DBPASS $OXI_TEST_DB_MYSQL_NAME

INSERT INTO `aliases` (`identifier`,`pki_realm`,`alias`,`group_id`,`generation`,`notafter`,`notbefore`) VALUES ('NZA-k3-yaMBQdsiAkbcfAeo8vQo','ca-one','ca-one-scep-1','ca-one-scep',1,4294967295,1485469746);
INSERT INTO `aliases` (`identifier`,`pki_realm`,`alias`,`group_id`,`generation`,`notafter`,`notbefore`) VALUES ('mIqp8XGxjquD0MtxsiFhv7JFfGk','ca-one','ca-one-signer-1','ca-one-signer',1,4294967295,1485469746);
INSERT INTO `aliases` (`identifier`,`pki_realm`,`alias`,`group_id`,`generation`,`notafter`,`notbefore`) VALUES ('IPkm4dSkDn1oPuWIRZjIxvvpsno','ca-one','ca-one-vault-1','ca-one-vault',1,4294967295,1485469746);
INSERT INTO `aliases` (`identifier`,`pki_realm`,`alias`,`group_id`,`generation`,`notafter`,`notbefore`) VALUES ('iBAq6FOll0nqgIvHx3ocq2TZg94','ca-one','root-1','root',1,4294967295,1485469746);

INSERT INTO `certificate` (`pki_realm`,`issuer_dn`,`cert_key`,`issuer_identifier`,`identifier`,`subject`,`status`,`subject_key_identifier`,`authority_key_identifier`,`notbefore`,`notafter`,`req_key`,`data`) VALUES ('ca-one','CN=Root CA,OU=Test CA,DC=OpenXPKI,DC=ORG',1,'iBAq6FOll0nqgIvHx3ocq2TZg94','mIqp8XGxjquD0MtxsiFhv7JFfGk','CN=CA ONE,OU=Test CA,DC=OpenXPKI,DC=ORG','ISSUED','C0:2B:40:43:26:D3:98:8C:4D:2A:30:32:5F:30:D8:24:AA:26:4E:2D','43:EF:7A:11:FC:96:8B:35:6D:56:CC:17:C2:63:68:73:3C:B3:57:8D',1485469746,4294967295,NULL,'-----BEGIN CERTIFICATE-----\nMIIDgjCCAmqgAwIBAgIBATANBgkqhkiG9w0BAQsFADBTMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxEDAOBgNVBAsMB1Rlc3Qg\nQ0ExEDAOBgNVBAMMB1Jvb3QgQ0EwIBcNMTcwMTI2MjIyOTA2WhgPMjExNzAxMDIy\nMjI5MDZaMFIxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghP\ncGVuWFBLSTEQMA4GA1UECwwHVGVzdCBDQTEPMA0GA1UEAwwGQ0EgT05FMIIBIjAN\nBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5NAB90bOO2fzfRvRQc/5Hu71t5ah\neSfWIqTU56EpVrqW7BKK8HgZs1mfYd/F+vImO3Vvs0szx9EoQsDLwXitzUR7qJKM\n2qt8BugvRS1LRoCKkrCa22SwmLXOKpD7sZZiKFLCC8+1qZ0PUBoHHGApVbmx3T64\nLCddxsUEaA8MEmyCd8VKd6I4wQwhS5oSo517V18k+OLA3BBXvmnjRMiZ4qCkxMbo\nYF/p/LWyLd+0CF0UrpIOo8B5lqdwtPTnQbbi29TJbGjjSzo4e7gQle7cadP3KFjT\n9EyMP8h/nXn3mjj4fVQESz8I8O4DV0TCkJtmDX2OOZ7FpVFGVU0F7d6PRwIDAQAB\no2AwXjAdBgNVHQ4EFgQUwCtAQybTmIxNKjAyXzDYJKomTi0wHwYDVR0jBBgwFoAU\nQ+96EfyWizVtVswXwmNoczyzV40wDwYDVR0TAQH/BAUwAwEB/zALBgNVHQ8EBAMC\nAQYwDQYJKoZIhvcNAQELBQADggEBALJWwfZGpOSSaYCh0yhBzLFntl+YCLnRb3L7\nAbVJTV1iB+8aP4k1N7GY/EO9cEBxgHb+hcX3pxpszwqCiGRzxWnOhhHeDkg7Q2zP\nfAJ6DlN+A9w29ffHjAB88yLmTth55X0Ek5ix7lPIlOPNmBTQ9aXjCJPG7XtEl+xz\ncIb7LUwUjlfUaIwf8WZb33e5C5GIptYUMZIktWkmI+rZ9aym9F4hy5Bx1tSHRfJV\npzTZ/NP4qhEi5eAXpj3LIC+UAdpflN4pTTMtTyE9RTR0k4nHQDjGeuWBrzZX3pc5\nXFW6Jm044cydqEzTKYDTEjH6zvhlfZmIHBbcpr34ZwldiXjbFE4=\n-----END CERTIFICATE-----');
INSERT INTO `certificate` (`pki_realm`,`issuer_dn`,`cert_key`,`issuer_identifier`,`identifier`,`subject`,`status`,`subject_key_identifier`,`authority_key_identifier`,`notbefore`,`notafter`,`req_key`,`data`) VALUES ('ca-one','CN=Root CA,OU=Test CA,DC=OpenXPKI,DC=ORG',2,'iBAq6FOll0nqgIvHx3ocq2TZg94','NZA-k3-yaMBQdsiAkbcfAeo8vQo','CN=SCEP,OU=Test CA,DC=OpenXPKI,DC=ORG','ISSUED','48:7F:FC:68:9A:B9:16:12:3A:60:C1:BA:D1:6A:EA:0D:24:8A:98:09','43:EF:7A:11:FC:96:8B:35:6D:56:CC:17:C2:63:68:73:3C:B3:57:8D',1485469746,4294967295,NULL,'-----BEGIN CERTIFICATE-----\nMIIDbTCCAlWgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBTMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxEDAOBgNVBAsMB1Rlc3Qg\nQ0ExEDAOBgNVBAMMB1Jvb3QgQ0EwIBcNMTcwMTI2MjIyOTA2WhgPMjExNzAxMDIy\nMjI5MDZaMFAxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghP\ncGVuWFBLSTEQMA4GA1UECwwHVGVzdCBDQTENMAsGA1UEAwwEU0NFUDCCASIwDQYJ\nKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKJ32slxCXRjRadtwG0y1YA50BdKvTIh\n8ZSUf6tCGnP6/v0QZAmFUX98emAknkAuAY+84wjm/JUFV4jRbr9cnt8COKMhE9bY\n6sL36Qylul97mcfxuD/7rSzAatOieodlteGJKb3tMGRbQPe3WGH7EB29NA+NnKWw\n5ra4vP8GlhqAYi9sKdnew5z7qKNRf1lTu1kI+v0aryMQObzO+v2TrK1kHArTg53q\nx6ctCCZOtgrNchGKRdB4vT+N6KD3G7taUISJzKTSoztCd0a+URv80OOyucfvV2VG\nK8Wyzun2rd7o2JqJuGfaHA7Mq1iMcq0W6md7zsLt4ZwcF6nUqhtYMP8CAwEAAaNN\nMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUSH/8aJq5FhI6YMG60WrqDSSKmAkwHwYD\nVR0jBBgwFoAUQ+96EfyWizVtVswXwmNoczyzV40wDQYJKoZIhvcNAQELBQADggEB\nAL78vaGME0wKR0PY4uqglWvTWyOzd/AqjvQGd1Y7TlcywXSYtMbRDiA4Ix4M4NLX\n/iAgjihadbQv0WOc/lvOfFplS+THnioMoz5U121//jiQJ8XB+sb8lDsz/iVevQ0/\nSm/xspfsML317Q+/C1Uo7TMCebw4QgZRVscGsSgZo4gQyriwCCdF2lt4jYB92Yu6\niymGmWm7nHrR+J7WVbMxd0NZicycOz6QOOGYXqAH61Fqty8h5Dc/7p2oKRaRHDj4\nPtKd5KbVlgVATIuizUsp34eIHwu+sXa4yoNM4RcYvz/OQB8C0Kv9XFTadEvBPGf6\nObbXnR37SfSv8ezX26Tscrc=\n-----END CERTIFICATE-----');
INSERT INTO `certificate` (`pki_realm`,`issuer_dn`,`cert_key`,`issuer_identifier`,`identifier`,`subject`,`status`,`subject_key_identifier`,`authority_key_identifier`,`notbefore`,`notafter`,`req_key`,`data`) VALUES (NULL,'CN=Root CA,OU=Test CA,DC=OpenXPKI,DC=ORG',16184103166370840861,'iBAq6FOll0nqgIvHx3ocq2TZg94','iBAq6FOll0nqgIvHx3ocq2TZg94','CN=Root CA,OU=Test CA,DC=OpenXPKI,DC=ORG','ISSUED','43:EF:7A:11:FC:96:8B:35:6D:56:CC:17:C2:63:68:73:3C:B3:57:8D','43:EF:7A:11:FC:96:8B:35:6D:56:CC:17:C2:63:68:73:3C:B3:57:8D',1485469746,4294967295,NULL,'-----BEGIN CERTIFICATE-----\nMIIDizCCAnOgAwIBAgIJAOCZfBUvzwEdMA0GCSqGSIb3DQEBCwUAMFMxEzARBgoJ\nkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTEQMA4GA1UE\nCwwHVGVzdCBDQTEQMA4GA1UEAwwHUm9vdCBDQTAgFw0xNzAxMjYyMjI5MDZaGA8y\nMTE3MDEwMjIyMjkwNlowUzETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMRAwDgYDVQQLDAdUZXN0IENBMRAwDgYDVQQDDAdSb290\nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyJV6fIoMScK9ceEa\n2JOBqBcws4D3DcHpekl39G/On3PB8mWGE9RN6VaEHiG8XJm8258SaVmPC0cpNaCN\nhVDahnymKI1fQSYw6/Jw/V2upQZIvTZ6Da8KKrZUdrXWMMTR0GqX+zQCIVSO3bAg\nictlInS39M2xLoRdGRvdzJHaJbk2PkUeZYWdzQLG/nSMmD+8kw7VXvgqZDlGXik5\niDWqMJq9P3BVcVQZUUoQQvfFPjYK6R4Jm9HMheJUxYc9ZdC8US5Ky9OvtehVU4yZ\nSjxSDQbD5bRaVutOt3E4aFXxLIl/aaKZ4AP//qnbXpY44Z9pUxeQldaW93Tl1bwN\n3XtjcQIDAQABo2AwXjAdBgNVHQ4EFgQUQ+96EfyWizVtVswXwmNoczyzV40wHwYD\nVR0jBBgwFoAUQ+96EfyWizVtVswXwmNoczyzV40wDwYDVR0TAQH/BAUwAwEB/zAL\nBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBAKLV/G0HGSxEU0V3Q1dsEQ9V\niZYMpB/fpL0wo3+b/ZEiMXRX2xPvJvwT1RMslNbYg+BYxwXm0kLeRRwg73ZXpP0h\niXocRonKah7KJrQ5vtb8ZGsbULHdnbbYdOIHJU/Je4U3B/lKHrh9PzSb4sXIg1Ld\nPYeO4sGZd8v1q70L+KFr1JQ8qPDjKJbaylIws4mm6h5AzjOa16lVw05xj9aabDmS\nazyFn67Jlp7z4kn0cNQ5LZll2vzQGTAcDaTqa7WVScm00UxbFa7KEc2op9HE2Bfb\nIhtMOnP4FXjvbK30oJ6D5EOhIqJmgrZFKLgD9CaV6iWTvnAfRrmP44r3qmnEO+E=\n-----END CERTIFICATE-----');
INSERT INTO `certificate` (`pki_realm`,`issuer_dn`,`cert_key`,`issuer_identifier`,`identifier`,`subject`,`status`,`subject_key_identifier`,`authority_key_identifier`,`notbefore`,`notafter`,`req_key`,`data`) VALUES ('ca-one','CN=DataVault,DC=OpenXPKI Internal',10782130252911634402,'IPkm4dSkDn1oPuWIRZjIxvvpsno','IPkm4dSkDn1oPuWIRZjIxvvpsno','CN=DataVault,DC=OpenXPKI Internal','ISSUED','20:1A:DE:5E:52:3F:AC:CD:91:97:0A:C6:D2:5A:44:C6:74:A0:B9:53','20:1A:DE:5E:52:3F:AC:CD:91:97:0A:C6:D2:5A:44:C6:74:A0:B9:53',1485469746,4294967295,NULL,'-----BEGIN CERTIFICATE-----\nMIIDYjCCAkqgAwIBAgIJAJWh0la+ymfiMA0GCSqGSIb3DQEBCwUAMDcxITAfBgoJ\nkiaJk/IsZAEZFhFPcGVuWFBLSSBJbnRlcm5hbDESMBAGA1UEAwwJRGF0YVZhdWx0\nMCAXDTE3MDEyNjIyMjkwNloYDzIxMTcwMTAyMjIyOTA2WjA3MSEwHwYKCZImiZPy\nLGQBGRYRT3BlblhQS0kgSW50ZXJuYWwxEjAQBgNVBAMMCURhdGFWYXVsdDCCASIw\nDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANPp5D9NDqxIRFu86fAiCa3u1SDG\nYKqXJ3rl7KtzGYJygb/O6tkprWiFbhYP9g3lepBoJQNy8e/BuGN5bIjuFHS+FgVL\nyUyOwERCmL+WRS3EDWWGg+oTe0M64/RwcNVc5Xb22FQzsSZAUx+tt6npVVJtLL+s\nJgseXkhOTyplQOemDDu+qqpgZAK2khsXfRR0TbuprMlwf7KHBJTJkWd3xJEXJO27\nEDKq4ioygR08jIneg1T5rxVENatEtmrEOLlcAm7lWVx9zVrUtmg3YWQ6Ze8NC2J9\nybuiOiVcqQMx3bdV/31azlnwlm9e/wf0FYjnmTmDkXQ+bwC5jMusYlkOiv8CAwEA\nAaNvMG0wCQYDVR0TBAIwADAdBgNVHQ4EFgQUIBreXlI/rM2RlwrG0lpExnSguVMw\nHwYDVR0jBBgwFoAUIBreXlI/rM2RlwrG0lpExnSguVMwCwYDVR0PBAQDAgUgMBMG\nA1UdJQQMMAoGCCsGAQUFBwMEMA0GCSqGSIb3DQEBCwUAA4IBAQBZvsVESue/IJa6\nE5+dfFO3keVUi9nB+1riyo/N3ZKCjhXev0vvNYdFyJWWJZUn+YpHVkcGt4H0B9tJ\nnEfQi2nWrLryQVEbBZg36SGODHyxCnOWzAyy+aYr6TS8W0Cf1GGYfhvToEy1A+QX\nbQZqsh0fD8+k+nmm1xGhMUQf5tC8tboEFvpN+4lyxjNlp0d8l9bElVEotjQreJrp\nf1rzzBZOx5cARYZa0iEFa5Ciwok73FMi+Y5JNjBPtwQVfunw6ECI8qO5Eg681GqK\nSCtHGFMene9rwFFj0wpQ7oogQLfQqQSDKkxcYRlOr2QDZQ5C8zicmSLNrJMQnJNp\nRULPx/So\n-----END CERTIFICATE-----');

__SQL
