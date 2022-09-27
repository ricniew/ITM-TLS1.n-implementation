# This file must sourced (". .\init_tlsv1.2.ps1") before starting "activate_teps-tlvs.ps1" procedure.
# For new TLS version copy this file and change values if required
# Do not modify this file.
# 20.07.2022: Version 2.0      R. Niewolik EMEA AVP Team 
#             - initial version                 
# 22.07.2022: Version 2.1      R. Niewolik EMEA AVP Team
#             - modfied KDEBE_TLSVNN_CIPHER_SPECS and JAVASEC_DISABLED_ALGORITHMS with new values
# 20.09.2023: Version 2.3      R. Niewolik EMEA AVp Team
#             - Removed KFW_ORB_ENABLED_PROTOCOLS now set in modcqini function
#             - Added check for TLSVER syntax

$global:TLSVER = "TLSv1.2"
$pattern = "^TLSv[0-9]\.[0-9]"
if ( $TLSVER -notmatch $pattern ) {
    write-host "ERROR - init_tls - Variable TLSVER=$TLSVER . Value is not correct. It should be in format 'TLSvn.n' for example 'TLSv1.2'."
    return 1
}

$global:KDEBE_TLSVNN_CIPHER_SPECS="TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"

$global:KDEBE_TLS_DISABLE="TLS10,TLS11"

$global:HTTP_SSLCIPHERSPEC="ALL -SSL_RSA_WITH_3DES_EDE_CBC_SHA"

$global:JAVASEC_DISABLED_ALGORITHMS="SSLv3, TLSv1, TLSv1.1, RC4, DES, SHA1, DHE, MD5withRSA, DH keySize < 2048, DESede, \ EC keySize < 224, 3DES_EDE_CBC, anon, NULL, DES_CBC"

write-host "INFO - TLSVER=$TLSVER"
write-host "INFO - KDEBE_TLSVNN_CIPHER_SPECS=$KDEBE_TLSVNN_CIPHER_SPECS"
write-host "INFO - KDEBE_TLS_DISABLE=$KDEBE_TLS_DISABLE"
write-host "INFO - HTTP_SSLCIPHERSPEC=$HTTP_SSLCIPHERSPEC"
write-host "INFO - JAVASEC_DISABLED_ALGORITHMS=$JAVASEC_DISABLED_ALGORITHMS"