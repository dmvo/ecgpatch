#include <stdint.h>
#include <string.h>
#include "nordic_common.h"
#include "nrf.h"
#include "app_error.h"
#include "nrf51_bitfields.h"
#include "ble.h"
#include "ble_hci.h"
#include "ble_srv_common.h"
#include "ble_advdata.h"
#include "ble_bas.h"
#include "ble_hrs.h"
#include "ble_conn_params.h"
#include "softdevice_handler.h"
#include "app_timer.h"
#include "ble_error_log.h"
#include "ble_debug_assert_handler.h"

#include "qrsdet.h"

#define DEVICE_NAME                          "Electria_HRM"                               /**< Name of device. Will be included in the advertising data. */
#define MANUFACTURER_NAME                    "NordicSemiconductor"                      /**< Manufacturer. Will be passed to Device Information Service. */
#define APP_ADV_INTERVAL                     40                                         /**< The advertising interval (in units of 0.625 ms. This value corresponds to 25 ms). */
#define APP_ADV_TIMEOUT_IN_SECONDS           180                                        /**< The advertising timeout in units of seconds. */

#define APP_TIMER_PRESCALER                  0                                          /**< Value of the RTC1 PRESCALER register. */
#define APP_TIMER_MAX_TIMERS                 3                                          /**< Maximum number of simultaneously created timers. */
#define APP_TIMER_OP_QUEUE_SIZE              4                                          /**< Size of timer operation queues. */

#define ADC_MEAS_INTERVAL             APP_TIMER_TICKS(5, APP_TIMER_PRESCALER)

#define MIN_CONN_INTERVAL                    MSEC_TO_UNITS(7.5, UNIT_1_25_MS)
#define MAX_CONN_INTERVAL                    MSEC_TO_UNITS(35, UNIT_1_25_MS)
#define SLAVE_LATENCY                        0                                          /**< Slave latency. */
#define CONN_SUP_TIMEOUT                     MSEC_TO_UNITS(4000, UNIT_10_MS)           /**< Connection supervisory timeout (4 seconds). */

#define FIRST_CONN_PARAMS_UPDATE_DELAY       APP_TIMER_TICKS(5000, APP_TIMER_PRESCALER) /**< Time from initiating event (connect or start of notification) to first time sd_ble_gap_conn_param_update is called (5 seconds). */
#define NEXT_CONN_PARAMS_UPDATE_DELAY        APP_TIMER_TICKS(5000, APP_TIMER_PRESCALER) /**< Time between each call to sd_ble_gap_conn_param_update after the first call (30 seconds). */
#define MAX_CONN_PARAMS_UPDATE_COUNT         3                                          /**< Number of attempts before giving up the connection parameter negotiation. */

#define SEC_PARAM_TIMEOUT                    30                                         /**< Timeout for Pairing Request or Security Request (in seconds). */
#define SEC_PARAM_BOND                       0                                          /**< Perform bonding. */
#define SEC_PARAM_MITM                       0                                          /**< Man In The Middle protection not required. */
#define SEC_PARAM_IO_CAPABILITIES            BLE_GAP_IO_CAPS_NONE                       /**< No I/O capabilities. */
#define SEC_PARAM_OOB                        0                                          /**< Out Of Band data not available. */
#define SEC_PARAM_MIN_KEY_SIZE               7                                          /**< Minimum encryption key size. */
#define SEC_PARAM_MAX_KEY_SIZE               16                                         /**< Maximum encryption key size. */

#define DEAD_BEEF                            0xDEADBEEF                                 /**< Value used as error code on stack dump, can be used to identify stack location on stack unwind. */

static uint16_t                              m_conn_handle = BLE_CONN_HANDLE_INVALID;   /**< Handle of the current connection. */
static ble_gap_sec_params_t                  m_sec_params;                              /**< Security requirements for this application. */
static ble_gap_adv_params_t                  m_adv_params;                              /**< Parameters to be passed to the stack when starting advertising. */
static ble_hrs_t                             m_hrs;                                     /**< Structure used to identify the heart rate service. */
static ble_bas_t                             m_bas;

static app_timer_id_t                        m_adc_timer_id;

static volatile uint16_t        s_cur_heart_rate;

static bool high_precision = false;

#define ADC_ECG_SAMPLE ((ADC_CONFIG_RES_10bit << ADC_CONFIG_RES_Pos) | \
	(ADC_CONFIG_INPSEL_AnalogInputOneThirdPrescaling << ADC_CONFIG_INPSEL_Pos) | \
	(ADC_CONFIG_REFSEL_VBG << ADC_CONFIG_REFSEL_Pos) | \
	(ADC_CONFIG_PSEL_AnalogInput2 << ADC_CONFIG_PSEL_Pos) | \
	(ADC_CONFIG_EXTREFSEL_None << ADC_CONFIG_EXTREFSEL_Pos))

void app_error_handler(uint32_t error_code, uint32_t line_num, const uint8_t * p_file_name)
{
    // This call can be used for debug purposes during application development.
    // @note CAUTION: Activating this code will write the stack to flash on an error.
    //                This function should NOT be used in a final product.
    //                It is intended STRICTLY for development/debugging purposes.
    //                The flash write will happen EVEN if the radio is active, thus interrupting
    //                any communication.
    //                Use with care. Uncomment the line below to use.
    // ble_debug_assert_handler(error_code, line_num, p_file_name);

    // On assert, the system can only recover with a reset.
    NVIC_SystemReset();
}

void assert_nrf_callback(uint16_t line_num, const uint8_t * p_file_name)
{
    app_error_handler(DEAD_BEEF, line_num, p_file_name);
}

static void adc_meas_timeout_handler(void *p_context)
{
	uint32_t hfclk_running = 0;

	if (high_precision) {
		sd_clock_hfclk_request();

		while (!hfclk_running)
			sd_clock_hfclk_is_running(&hfclk_running);
	}

	NRF_ADC->TASKS_START = 1;
}

static void timers_init(void)
{
	uint32_t err_code;

	APP_TIMER_INIT(APP_TIMER_PRESCALER, APP_TIMER_MAX_TIMERS, APP_TIMER_OP_QUEUE_SIZE, false);

	err_code = app_timer_create(&m_adc_timer_id,
			APP_TIMER_MODE_REPEATED,
			adc_meas_timeout_handler);
	APP_ERROR_CHECK(err_code);
}

static void gap_params_init(void)
{
	uint32_t                err_code;
	ble_gap_conn_params_t   gap_conn_params;
	ble_gap_conn_sec_mode_t sec_mode;

	BLE_GAP_CONN_SEC_MODE_SET_OPEN(&sec_mode);

	err_code = sd_ble_gap_device_name_set(&sec_mode,
			(const uint8_t *)DEVICE_NAME,
			strlen(DEVICE_NAME));
	APP_ERROR_CHECK(err_code);

	err_code = sd_ble_gap_appearance_set(BLE_APPEARANCE_HEART_RATE_SENSOR_HEART_RATE_BELT);
	APP_ERROR_CHECK(err_code);

	memset(&gap_conn_params, 0, sizeof(gap_conn_params));

	gap_conn_params.min_conn_interval = MIN_CONN_INTERVAL;
	gap_conn_params.max_conn_interval = MAX_CONN_INTERVAL;
	gap_conn_params.slave_latency     = SLAVE_LATENCY;
	gap_conn_params.conn_sup_timeout  = CONN_SUP_TIMEOUT;

	err_code = sd_ble_gap_ppcp_set(&gap_conn_params);
	APP_ERROR_CHECK(err_code);
}

static void advertising_init(void)
{
	uint32_t      err_code;
	ble_advdata_t advdata;
	uint8_t       flags = BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE;

	ble_uuid_t adv_uuids[] =
	{
		{BLE_UUID_HEART_RATE_SERVICE, BLE_UUID_TYPE_BLE},
		{BLE_UUID_BATTERY_SERVICE, BLE_UUID_TYPE_BLE},
	};

	// Build and set advertising data.
	memset(&advdata, 0, sizeof(advdata));

	advdata.name_type               = BLE_ADVDATA_FULL_NAME;
	advdata.include_appearance      = true;
	advdata.flags.size              = sizeof(flags);
	advdata.flags.p_data            = &flags;
	advdata.uuids_complete.uuid_cnt = sizeof(adv_uuids) / sizeof(adv_uuids[0]);
	advdata.uuids_complete.p_uuids  = adv_uuids;

	err_code = ble_advdata_set(&advdata, NULL);
	APP_ERROR_CHECK(err_code);

	// Initialize advertising parameters (used when starting advertising).
	memset(&m_adv_params, 0, sizeof(m_adv_params));

	m_adv_params.type        = BLE_GAP_ADV_TYPE_ADV_IND;
	m_adv_params.p_peer_addr = NULL;                           // Undirected advertisement.
	m_adv_params.fp          = BLE_GAP_ADV_FP_ANY;
	m_adv_params.interval    = APP_ADV_INTERVAL;
	m_adv_params.timeout     = APP_ADV_TIMEOUT_IN_SECONDS;
}

static void services_init(void)
{
	uint32_t       err_code;
	ble_hrs_init_t hrs_init;
	ble_bas_init_t bas_init;
	uint8_t        body_sensor_location;

	/* Initialize Heart Rate Service. */
	body_sensor_location = BLE_HRS_BODY_SENSOR_LOCATION_CHEST;

	memset(&hrs_init, 0, sizeof(hrs_init));

	hrs_init.evt_handler                 = NULL;
	hrs_init.is_sensor_contact_supported = false;
	hrs_init.p_body_sensor_location      = &body_sensor_location;

	/* Here the sec level for the Heart Rate Service can be changed/increased. */
	BLE_GAP_CONN_SEC_MODE_SET_OPEN(&hrs_init.hrs_hrm_attr_md.cccd_write_perm);
	BLE_GAP_CONN_SEC_MODE_SET_NO_ACCESS(&hrs_init.hrs_hrm_attr_md.read_perm);
	BLE_GAP_CONN_SEC_MODE_SET_NO_ACCESS(&hrs_init.hrs_hrm_attr_md.write_perm);

	BLE_GAP_CONN_SEC_MODE_SET_OPEN(&hrs_init.hrs_bsl_attr_md.read_perm);
	BLE_GAP_CONN_SEC_MODE_SET_NO_ACCESS(&hrs_init.hrs_bsl_attr_md.write_perm);

	err_code = ble_hrs_init(&m_hrs, &hrs_init);
	APP_ERROR_CHECK(err_code);

	/* Initialize Battery Service */
	memset(&bas_init, 0, sizeof(bas_init));

	/* Here the sec level for the Battery Service can be changed/increased. */
	BLE_GAP_CONN_SEC_MODE_SET_OPEN(&bas_init.battery_level_char_attr_md.cccd_write_perm);
	BLE_GAP_CONN_SEC_MODE_SET_OPEN(&bas_init.battery_level_char_attr_md.read_perm);
	BLE_GAP_CONN_SEC_MODE_SET_NO_ACCESS(&bas_init.battery_level_char_attr_md.write_perm);
	BLE_GAP_CONN_SEC_MODE_SET_OPEN(&bas_init.battery_level_report_read_perm);

	bas_init.evt_handler          = NULL;
	bas_init.support_notification = true;
	bas_init.p_report_ref         = NULL;
	bas_init.initial_batt_level   = 100;

	err_code = ble_bas_init(&m_bas, &bas_init);
	APP_ERROR_CHECK(err_code);
}

static void sec_params_init(void)
{
	m_sec_params.timeout      = SEC_PARAM_TIMEOUT;
	m_sec_params.bond         = SEC_PARAM_BOND;
	m_sec_params.mitm         = SEC_PARAM_MITM;
	m_sec_params.io_caps      = SEC_PARAM_IO_CAPABILITIES;
	m_sec_params.oob          = SEC_PARAM_OOB;
	m_sec_params.min_key_size = SEC_PARAM_MIN_KEY_SIZE;
	m_sec_params.max_key_size = SEC_PARAM_MAX_KEY_SIZE;
}

static void adc_init(void)
{
	NRF_ADC->INTENSET = ADC_INTENSET_END_Msk;   
	sd_nvic_SetPriority(ADC_IRQn, NRF_APP_PRIORITY_LOW);  
	sd_nvic_EnableIRQ(ADC_IRQn);
	NRF_ADC->CONFIG = ADC_ECG_SAMPLE;
	NRF_ADC->ENABLE = ADC_ENABLE_ENABLE_Enabled;
}

static void application_timers_start(void)
{
	uint32_t err_code;

	err_code = app_timer_start(m_adc_timer_id, ADC_MEAS_INTERVAL, NULL);
	APP_ERROR_CHECK(err_code);
}

static void advertising_start(void)
{
	uint32_t err_code;

	err_code = sd_ble_gap_adv_start(&m_adv_params);
	APP_ERROR_CHECK(err_code);
}

static void on_conn_params_evt(ble_conn_params_evt_t *p_evt)
{
	uint32_t err_code;

	if(p_evt->evt_type == BLE_CONN_PARAMS_EVT_FAILED)
	{
		err_code = sd_ble_gap_disconnect(m_conn_handle, BLE_HCI_CONN_INTERVAL_UNACCEPTABLE);
		APP_ERROR_CHECK(err_code);
	}
}

static void conn_params_error_handler(uint32_t nrf_error)
{
    APP_ERROR_HANDLER(nrf_error);
}

static void conn_params_init(void)
{
	uint32_t               err_code;
	ble_conn_params_init_t cp_init;

	memset(&cp_init, 0, sizeof(cp_init));

	cp_init.p_conn_params                  = NULL;
	cp_init.first_conn_params_update_delay = FIRST_CONN_PARAMS_UPDATE_DELAY;
	cp_init.next_conn_params_update_delay  = NEXT_CONN_PARAMS_UPDATE_DELAY;
	cp_init.max_conn_params_update_count   = MAX_CONN_PARAMS_UPDATE_COUNT;
	cp_init.start_on_notify_cccd_handle    = m_hrs.hrm_handles.cccd_handle;
	cp_init.disconnect_on_fail             = false;
	cp_init.evt_handler                    = on_conn_params_evt;
	cp_init.error_handler                  = conn_params_error_handler;

	err_code = ble_conn_params_init(&cp_init);
	APP_ERROR_CHECK(err_code);
}

static void on_ble_evt(ble_evt_t * p_ble_evt)
{
    uint32_t err_code;

    switch (p_ble_evt->header.evt_id)
    {
        case BLE_GAP_EVT_CONNECTED:

            m_conn_handle = p_ble_evt->evt.gap_evt.conn_handle;
            break;

        case BLE_GAP_EVT_DISCONNECTED:

            m_conn_handle = BLE_CONN_HANDLE_INVALID;

            advertising_start();
            break;

        case BLE_GAP_EVT_SEC_PARAMS_REQUEST:
            err_code = sd_ble_gap_sec_params_reply(m_conn_handle,
                                                   BLE_GAP_SEC_STATUS_SUCCESS,
                                                   &m_sec_params);
            APP_ERROR_CHECK(err_code);
            break;

        case BLE_GAP_EVT_TIMEOUT:
            if (p_ble_evt->evt.gap_evt.params.timeout.src == BLE_GAP_TIMEOUT_SRC_ADVERTISEMENT)
            {
                err_code = sd_power_system_off();
                APP_ERROR_CHECK(err_code);
            }
            break;

        default:
            break;
    }
}

void ADC_IRQHandler(void)
{
	volatile uint32_t result;
	static uint32_t ticks, prev_ticks;
	uint32_t delay;
	uint16_t rr_interval;
	uint32_t err_code;
	static bool tosend = true;

	NRF_ADC->EVENTS_END = 0;
	result = NRF_ADC->RESULT;
	NRF_ADC->TASKS_STOP = 1;

	if (high_precision)
		sd_clock_hfclk_release();

	delay = QRSDet(result, 0);

	if (delay) {
		prev_ticks = ticks;
		app_timer_cnt_get(&ticks);
		rr_interval = (60 * APP_TIMER_CLOCK_FREQ) / ((APP_TIMER_PRESCALER + 1) * (ticks - prev_ticks));
		ble_hrs_rr_interval_add(&m_hrs, rr_interval);
	}

	if (tosend) {
		s_cur_heart_rate = result;

		err_code = ble_hrs_heart_rate_measurement_send(&m_hrs, s_cur_heart_rate);
		if ((err_code != NRF_SUCCESS) && (err_code != NRF_ERROR_INVALID_STATE)
				&& (err_code != BLE_ERROR_NO_TX_BUFFERS)
				&& (err_code != BLE_ERROR_GATTS_SYS_ATTR_MISSING)) {
		}
	}

	tosend = !tosend;
}

static void ble_evt_dispatch(ble_evt_t * p_ble_evt)
{
	ble_bas_on_ble_evt(&m_bas, p_ble_evt);
	ble_hrs_on_ble_evt(&m_hrs, p_ble_evt);
	ble_conn_params_on_ble_evt(p_ble_evt);
	on_ble_evt(p_ble_evt);
}

static void sys_evt_dispatch(uint32_t sys_evt)
{
}

static void ble_stack_init(void)
{
	uint32_t err_code;

	SOFTDEVICE_HANDLER_INIT(NRF_CLOCK_LFCLKSRC_XTAL_20_PPM, false);

	err_code = softdevice_ble_evt_handler_set(ble_evt_dispatch);
	APP_ERROR_CHECK(err_code);

	err_code = softdevice_sys_evt_handler_set(sys_evt_dispatch);
	APP_ERROR_CHECK(err_code);
}

static void power_manage(void)
{
	uint32_t err_code = sd_app_evt_wait();
	APP_ERROR_CHECK(err_code);
}

int main(void)
{
	QRSDet(0, 1);	

	ble_stack_init();
	timers_init();
	adc_init();

	gap_params_init();
	advertising_init();
	services_init();
	conn_params_init();
	sec_params_init();

	application_timers_start();
	advertising_start();

	for (;;)
	{
		power_manage();
	}
}
