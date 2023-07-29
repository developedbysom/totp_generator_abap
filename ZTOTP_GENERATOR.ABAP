*&---------------------------------------------------------------------*
*& Report ZTOTP_GENERATOR
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ztotp_generator.

CLASS lcl_totp_generator DEFINITION CREATE PRIVATE .

  PUBLIC SECTION.

    CONSTANTS c_base32_allowed_chars TYPE string VALUE 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567' ##NO_TEXT.

    CLASS-METHODS get_instance
      IMPORTING
        !im_secret_key           TYPE string
        !im_otp_len              TYPE char2 DEFAULT '6'
        !im_validity_sec         TYPE char2 DEFAULT '30'
      RETURNING
        VALUE(ro_totp_generator) TYPE REF TO lcl_totp_generator .
    METHODS get_totp
      RETURNING
        VALUE(r_totp) TYPE string
      RAISING
        cx_demo_dyn_t100 .
  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_bin2hex ,
        bin TYPE char4,
        hex TYPE char1,
      END OF ty_bin2hex .
    TYPES:
      tt_bin2hex TYPE STANDARD TABLE OF ty_bin2hex WITH EMPTY KEY .
    TYPES:
      BEGIN OF ty_hex2dec,
        hex TYPE char1,
        dec TYPE char2,
      END OF ty_hex2dec .
    TYPES:
      tt_hex2dec TYPE STANDARD TABLE OF ty_hex2dec WITH EMPTY KEY .

    TYPES ty_pack TYPE p LENGTH 10 DECIMALS 0.

    CLASS-DATA o_totp_generator TYPE REF TO lcl_totp_generator .
    CLASS-DATA t_bin2hex TYPE tt_bin2hex .
    CLASS-DATA t_hex2dec TYPE tt_hex2dec .

    DATA w_otp_len TYPE char2 .
    DATA w_validity_sec TYPE i .
    DATA w_secret_key TYPE string .
    DATA w_restart_flag TYPE abap_bool .
    DATA w_key_hex_value TYPE string .
    DATA g_lastrun_timestmp TYPE timestamp.

    METHODS constructor .
    METHODS base32_to_hex
      IMPORTING
        !im_secret_key  TYPE string
      EXPORTING
        !ex_hexadecimal TYPE string
        !ex_rc          TYPE i .
    METHODS conv_dec_to_bin
      IMPORTING
        !im_decimal     TYPE i
        !im_base32_flag TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_bit)   TYPE string .
    METHODS conv_bin_to_hex
      IMPORTING
        !im_binary           TYPE string
        !im_epoch_flag       TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(r_hexadecimal) TYPE string .
    METHODS cal_epoch_unix_time
      RETURNING
        VALUE(r_epoch_unix_time) TYPE i .
    METHODS conv_epoch_to_hex
      RETURNING
        VALUE(r_hexadecimal) TYPE string .
    METHODS conv_dec_to_hex
      IMPORTING
        !im_decimal          TYPE i
      RETURNING
        VALUE(r_hexadecimal) TYPE string .
    METHODS conv_hex_to_dec
      IMPORTING
        !im_hexadecimal  TYPE xstring
      RETURNING
        VALUE(r_decimal) TYPE ty_pack .
ENDCLASS.

CLASS lcl_totp_generator IMPLEMENTATION.

* <Signature>---------------------------------------------------------------------------------------+
* | Instance Private Method LCL_TOTP_GENERATOR->BASE32_TO_HEX
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_SECRET_KEY                  TYPE        STRING
* | [<---] EX_HEXADECIMAL                 TYPE        STRING
* | [<---] EX_RC                          TYPE        I
* +--------------------------------------------------------------------------------------</Signature>
  METHOD base32_to_hex.

    DATA: l_bit            TYPE string,
          l_bit_collection TYPE string.

    CLEAR :ex_hexadecimal, ex_rc.

    DO strlen( w_secret_key ) TIMES.
*--GET EACH CHAR
      DATA(l_offset) = sy-index - 1.
      DATA(l_char) =  w_secret_key+l_offset(1).

*---Getting the position in allowed list of characters
      FIND FIRST OCCURRENCE OF l_char IN c_base32_allowed_chars
       MATCH OFFSET DATA(l_index).
      IF sy-subrc EQ 0.
        l_bit_collection = l_bit_collection &&
                me->conv_dec_to_bin( im_decimal = l_index im_base32_flag = abap_true ).
      ELSE.
        ex_rc = 4.
        RETURN.
      ENDIF.

    ENDDO.

    w_key_hex_value = conv_bin_to_hex( im_binary = l_bit_collection ).
    ex_hexadecimal  = w_key_hex_value.

  ENDMETHOD.


* <Signature>---------------------------------------------------------------------------------------+
* | Instance Private Method lcl_TOTP_GENERATOR->conv_bin_to_hex
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_BINARY                      TYPE        STRING
* | [--->] IM_EPOCH_FLAG                  TYPE        ABAP_BOOL (default =ABAP_FALSE)
* | [<-()] R_HEXADECIMAL                  TYPE        STRING
* +--------------------------------------------------------------------------------------</Signature>
  METHOD conv_bin_to_hex.

    DATA :l_binary TYPE string,
          l_hex    TYPE string,
          l_offset TYPE syindex VALUE 0.

    l_binary = im_binary.

*---When epoch to convert
    IF im_epoch_flag = abap_true.

*---Left Padding with Zeros
      DATA(l_remainder) = strlen( l_binary ) MOD 4.
      IF l_remainder GT 0.
        DATA(l_padding) = 4 - l_remainder.

        DO l_padding TIMES.
          l_binary = '0' && l_binary.
        ENDDO.

      ENDIF.

      DO.
        TRY.
            DATA(l_bits) = l_binary+l_offset(4).
          CATCH cx_sy_range_out_of_bounds.
            EXIT.
        ENDTRY.
        l_offset = l_offset + 4.
        l_hex = l_hex && |{ VALUE #( t_bin2hex[ bin = l_bits ]-hex OPTIONAL ) }|.
      ENDDO.

    ELSE.

*--- When Base32 or other scenarios
      DO.
        TRY.
            l_bits = l_binary+l_offset(8).
          CATCH cx_sy_range_out_of_bounds.
            EXIT.
        ENDTRY.
        l_offset = l_offset + 8.
        l_hex = l_hex && |{ VALUE #( t_bin2hex[ bin = l_bits(4) ]-hex OPTIONAL ) }|.
        l_hex = l_hex && |{ VALUE #( t_bin2hex[ bin = l_bits+4(4) ]-hex OPTIONAL ) }|.
      ENDDO.

    ENDIF.

    CLEAR  r_hexadecimal.
    r_hexadecimal = l_hex.
  ENDMETHOD.


* <Signature>---------------------------------------------------------------------------------------+
* | Instance Private Method lcl_TOTP_GENERATOR->CAL_EPOCH_UNIX_TIME
* +-------------------------------------------------------------------------------------------------+
* | [<-()] R_EPOCH_UNIX_TIME              TYPE        I
* +--------------------------------------------------------------------------------------</Signature>
  METHOD cal_epoch_unix_time.

    DATA l_tstamp TYPE timestamp.

    CHECK me->w_validity_sec > 0.

*---get current timestamp
    GET TIME STAMP FIELD l_tstamp .
    me->g_lastrun_timestmp = l_tstamp .

*---Convert to UTC time zone

    CONVERT TIME STAMP l_tstamp TIME ZONE 'UTC'
            INTO DATE DATA(l_date) TIME DATA(l_time)
            DAYLIGHT SAVING TIME DATA(l_dst).

    CALL METHOD cl_pco_utility=>convert_abap_timestamp_to_java
      EXPORTING
        iv_date      = l_date
        iv_time      = l_time
      IMPORTING
        ev_timestamp = DATA(l_java_timestamp).

    r_epoch_unix_time = floor( floor( l_java_timestamp / 1000 ) / me->w_validity_sec ).

  ENDMETHOD.


* <Signature>---------------------------------------------------------------------------------------+
* | Instance Private Method lcl_TOTP_GENERATOR->CONSTRUCTOR
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</Signature>
  METHOD constructor.

    t_bin2hex = VALUE #(
                         ( bin = '0000' hex = '0' )
                         ( bin = '0001' hex = '1' )
                         ( bin = '0010' hex = '2' )
                         ( bin = '0011' hex = '3' )
                         ( bin = '0100' hex = '4' )
                         ( bin = '0101' hex = '5' )
                         ( bin = '0110' hex = '6' )
                         ( bin = '0111' hex = '7' )
                         ( bin = '1000' hex = '8' )
                         ( bin = '1001' hex = '9' )
                         ( bin = '1010' hex = 'A' )
                         ( bin = '1011' hex = 'B' )
                         ( bin = '1100' hex = 'C' )
                         ( bin = '1101' hex = 'D' )
                         ( bin = '1110' hex = 'E' )
                         ( bin = '1111' hex = 'F' )
                      ).

    t_hex2dec = VALUE #(
                          ( hex = '0' dec = '0' )
                          ( hex = '1' dec = '1' )
                          ( hex = '2' dec = '2' )
                          ( hex = '3' dec = '3' )
                          ( hex = '4' dec = '4' )
                          ( hex = '5' dec = '5' )
                          ( hex = '6' dec = '6' )
                          ( hex = '7' dec = '7' )
                          ( hex = '8' dec = '8' )
                          ( hex = '9' dec = '9' )
                          ( hex = 'A' dec = '10' )
                          ( hex = 'B' dec = '11' )
                          ( hex = 'C' dec = '12' )
                          ( hex = 'D' dec = '13' )
                          ( hex = 'E' dec = '14' )
                          ( hex = 'F' dec = '15' )
                       ).
  ENDMETHOD.


* <Signature>---------------------------------------------------------------------------------------+
* | Instance Private Method lcl_TOTP_GENERATOR->CONV_DEC_TO_HEX
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_DECIMAL                     TYPE        I
* | [<-()] R_HEXADECIMAL                  TYPE        STRING
* +--------------------------------------------------------------------------------------</Signature>
  METHOD conv_dec_to_hex.

    DATA :l_bin TYPE string.

    l_bin = conv_dec_to_bin( im_decimal = im_decimal im_base32_flag = abap_false ).

    r_hexadecimal = conv_bin_to_hex( im_binary = l_bin im_epoch_flag = abap_true ).
  ENDMETHOD.


* <Signature>---------------------------------------------------------------------------------------+
* | Instance Private Method lcl_TOTP_GENERATOR->CONV_EPOCH_TO_HEX
* +-------------------------------------------------------------------------------------------------+
* | [<-()] R_HEXADECIMAL                  TYPE        STRING
* +--------------------------------------------------------------------------------------</Signature>
  METHOD conv_epoch_to_hex.

    DATA: l_epoch  TYPE i,
          l_char16 TYPE char16,
          l_hex    TYPE string.

    GET TIME STAMP FIELD DATA(l_tstamp).

    SELECT SINGLE * FROM ztotplog
        INTO @DATA(lwa_ztotplog)
        WHERE userid = @sy-uname.
    IF sy-subrc <> 0.

      l_epoch = cal_epoch_unix_time( ).
      l_hex  = conv_dec_to_hex( im_decimal = l_epoch ).

      lwa_ztotplog-userid = sy-uname.
      lwa_ztotplog-epoch = l_epoch .
      lwa_ztotplog-timestamp = me->g_lastrun_timestmp.

      INSERT ztotplog FROM lwa_ztotplog.
      COMMIT WORK.

    ELSE.

      IF ( l_tstamp - lwa_ztotplog-timestamp )
                    GT me->w_validity_sec.

        l_epoch = cal_epoch_unix_time( ).
        l_hex  = conv_dec_to_hex( im_decimal = l_epoch ).

        lwa_ztotplog-userid = sy-uname.
        lwa_ztotplog-epoch = l_epoch .
        lwa_ztotplog-timestamp = me->g_lastrun_timestmp.
        MODIFY  ztotplog FROM lwa_ztotplog.
        COMMIT WORK.

      ELSE.

        l_hex  = conv_dec_to_hex( im_decimal = lwa_ztotplog-epoch ).

      ENDIF.

    ENDIF.

    l_char16 = l_hex.

    DATA(l_len) = strlen( l_char16 ).

    DO  16 - l_len TIMES.
      l_char16  = '0' &&  l_char16 .
    ENDDO.

    r_hexadecimal = l_char16.

  ENDMETHOD.


* <Signature>---------------------------------------------------------------------------------------+
* | Instance Private Method lcl_TOTP_GENERATOR->CONV_HEX_TO_DEC
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_HEXADECIMAL                 TYPE        XSTRING
* | [<-()] R_DECIMAL                      TYPE        TY_PACK
* +--------------------------------------------------------------------------------------</Signature>
  METHOD conv_hex_to_dec.

    DATA:l_hmac_val    TYPE string,
         l_dec         TYPE p LENGTH 16,
         l_hex_padding TYPE xstring VALUE '7FFFFFFF',
         l_hex2        TYPE xstring,
         l_offset_i    TYPE i.

    l_hmac_val = im_hexadecimal.

    DATA(l_val1) = strlen( l_hmac_val ) - 1.

    DATA(l_offset) = substring( val = l_hmac_val off = l_val1 len = 1 ).

    l_offset_i = VALUE #( t_hex2dec[ hex = l_offset ]-dec OPTIONAL ).

    DATA(l_hamc_sub) = substring( val = l_hmac_val off = l_offset_i * 2 len = 8 ).

    TRY.
        l_hex2 = l_hamc_sub.

        DATA(l_bitand)  = l_hex2 BIT-AND l_hex_padding.
        r_decimal = l_bitand.
      CATCH cx_root.

    ENDTRY.

  ENDMETHOD.


* <Signature>---------------------------------------------------------------------------------------+
* | Instance Private Method lcl_TOTP_GENERATOR->conv_dec_to_bin
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_DECIMAL                     TYPE        I
* | [--->] IM_BASE32_FLAG                 TYPE        ABAP_BOOL (default =ABAP_FALSE)
* | [<-()] RV_BIT                         TYPE        STRING
* +--------------------------------------------------------------------------------------</Signature>
  METHOD conv_dec_to_bin.

    DATA:l_quotient  TYPE i,
         l_divisible TYPE i,
         l_bit       TYPE string,
         l_bitn      TYPE numc5.

    l_divisible = im_decimal.

    DO.

      l_quotient =  l_divisible DIV 2 .
      l_bit =  |{ floor( l_divisible MOD 2 ) }| && l_bit.

      l_divisible =  l_quotient.

      IF l_quotient = 0.
        EXIT.
      ENDIF.

    ENDDO.

    IF im_base32_flag EQ abap_true.
      l_bitn = l_bit.
      rv_bit = |{ l_bitn ALPHA = IN }|.
    ELSE.
      rv_bit = l_bit.
    ENDIF.

  ENDMETHOD.


* <Signature>---------------------------------------------------------------------------------------+
* | Static Public Method lcl_TOTP_GENERATOR=>GET_INSTANCE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_SECRET_KEY                  TYPE        STRING
* | [--->] IM_OTP_LEN                     TYPE        CHAR2 (default ='6')
* | [--->] IM_VALIDITY_SEC                TYPE        CHAR2 (default ='30')
* | [<-()] RO_TOTP_GENERATOR              TYPE REF TO lcl_TOTP_GENERATOR
* +--------------------------------------------------------------------------------------</Signature>
  METHOD get_instance.

    IF o_totp_generator IS NOT BOUND.
      o_totp_generator = NEW #( ).
    ENDIF.

    IF   o_totp_generator->w_otp_len      <> im_otp_len
      OR o_totp_generator->w_validity_sec <> im_validity_sec
      OR o_totp_generator->w_secret_key   <> im_secret_key.

      o_totp_generator->w_otp_len      = im_otp_len.
      o_totp_generator->w_validity_sec = im_validity_sec.
      o_totp_generator->w_secret_key   = im_secret_key.
      o_totp_generator->w_restart_flag = abap_true.
    ELSE.
      o_totp_generator->w_restart_flag = abap_false.
    ENDIF.

    ro_totp_generator =  o_totp_generator.

  ENDMETHOD.


* <Signature>---------------------------------------------------------------------------------------+
* | Instance Public Method lcl_TOTP_GENERATOR->GET_TOTP
* +-------------------------------------------------------------------------------------------------+
* | [<-()] R_TOTP                         TYPE        STRING
* +--------------------------------------------------------------------------------------</Signature>
  METHOD get_totp.

    DATA:l_secret_hex TYPE string,
         l_totp       TYPE p,
         l_max        TYPE i,
         l_otp_str    TYPE string.

*---First calculate the hex value of input key
    IF w_restart_flag EQ abap_true.
      me->base32_to_hex(
       EXPORTING im_secret_key = me->w_secret_key
       IMPORTING ex_hexadecimal = l_secret_hex ex_rc = DATA(l_rc)
      ).
      IF l_rc = 4.
        RAISE EXCEPTION TYPE cx_demo_dyn_t100
          MESSAGE ID 'Z1'
          TYPE 'E'
          NUMBER '000'
          WITH 'Secret key contains invalid Base32 character'.
      ENDIF.
    ELSE.
      l_secret_hex = me->w_key_hex_value.
    ENDIF.

*    WRITE:/ |Secret Hex: { l_secret_hex }|.

*---select last run log for the current user
    DATA(l_epoch_hex) = conv_epoch_to_hex( ).

*---Instanciating HMAC
    TRY.
        DATA(lo_hmac) = cl_abap_hmac=>get_instance(
                            if_key = CONV xstring( l_secret_hex )
                            ).
*---update with time factor (epoch unix time)
        lo_hmac->update( if_data = CONV xstring( l_epoch_hex ) ).

*---Finally ciollecting HMAC Hex data
        lo_hmac->final( IMPORTING ef_hmacxstring = DATA(l_hmac_hex) ).

      CATCH cx_abap_message_digest INTO DATA(l_error).

    ENDTRY.

    IF l_hmac_hex IS NOT INITIAL.
      DATA(l_otp) = conv_hex_to_dec( im_hexadecimal = l_hmac_hex ).

      l_otp_str =  l_otp .
      CONDENSE l_otp_str.

      DATA(l_val1) = strlen( l_otp_str ).

      l_val1 = l_val1 - me->w_otp_len.

      l_max = nmax( val1 = l_val1 val2 = 0 ).

      r_totp =  substring( val = CONV string( l_otp ) off = l_max len = me->w_otp_len ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.


PARAMETERS:p_key    TYPE char30 DEFAULT 'HELLOWORLD',
           p_len    TYPE char2 DEFAULT '6',
           p_period TYPE char2 DEFAULT '30'.

INITIALIZATION.

  %_p_key_%_app_%-text = 'Your Secret Key'.
  %_p_len_%_app_%-text = 'Number of Digits'.
  %_p_period_%_app_%-text = 'Token Period (In Seconds)'.

START-OF-SELECTION.
  TRY.
      DATA(l_otp) = lcl_totp_generator=>get_instance(
                  im_secret_key = CONV #( p_key )
                  im_otp_len = p_len
                  im_validity_sec = p_period
                  )->get_totp( ).
    CATCH cx_demo_dyn_t100 INTO DATA(lo_error).
      MESSAGE lo_error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
  ENDTRY.
  WRITE:/ |Secret Key: { p_key }|.
  WRITE:/ |Number of Digits: { p_len }|.
  WRITE:/ |TOKEN PERIOD (IN SECONDS): { p_period }|.
  WRITE:/ sy-uline.
  FORMAT INTENSIFIED COLOR = 4.
  WRITE:/ |TOTP: { l_otp }|.
