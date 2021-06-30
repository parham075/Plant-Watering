#include <time.h>
#include <WiFi.h>
#include <DHT.h>

#define VOL1 12
#define VOL2 13

#define S1P 34
#define S2P 35

#define DHTTYPE DHT22
#define DHTP 25

#define SSID "parniyan"
#define PSWD "14651465"

#define ntpServer "pool.ntp.org"
#define gmtOffset_sec 16200
#define daylightOffset_sec 0

struct TimeSt
{
public:
	int8_t h, m;

	TimeSt(int8_t h, int8_t m)
	{
		this->h = h;
		this->m = m;
	}
	int8_t getPastM(int8_t off_t_m)
	{
		int8_t res = m - off_t_m;
		if (res < 0)
			res += 60;
		return res;
	}
	int8_t getPastH(int8_t off_t_m)
	{
		int8_t mn = m - off_t_m;
		int8_t res = h;
		if (mn < 0)
		{
			res -= 1;
			if (res < 0)
				res += 24;
		}
		return res;
	}
};

TimeSt irrigation_1(0, 34);

TimeSt irrigation_2(2, 11);

TimeSt irrigation_3(12,45);

bool cancelIrrigation = false;

struct tm timeinfo;

IPAddress local_IP(192, 168, 1, 4);
IPAddress gateway(192, 168, 1, 1);
IPAddress subnet(255, 255, 255, 0);

WiFiServer server(80);

DHT dht(DHTP, DHTTYPE);

float air_temperature = 0, air_humidity = 0;
uint16_t soil_humidity_1 = 0, soil_humidity_2 = 0;




uint16_t Min_soil1t = 1500, Max_soil1t = 2000, Max_soil2t = 3000 ,Min_soil2t = 2500;





void blink(unsigned delay_ms)
{
	digitalWrite(LED_BUILTIN, HIGH);
	delay(delay_ms);
	digitalWrite(LED_BUILTIN, LOW);
	delay(delay_ms);
}
void getTime()
{
	if (!getLocalTime(&timeinfo))
		blink(2000);
}
void setupTime()
{
	WiFi.begin(SSID, PSWD);
	while (WiFi.status() != WL_CONNECTED)
		delay(120);
	configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
	getTime();
	WiFi.disconnect(true);
	WiFi.mode(WIFI_OFF);
}
void setVol(uint8_t vol1, uint8_t vol2)
{
	digitalWrite(VOL1, vol1);
	digitalWrite(VOL2, vol2);
}
void sendData(WiFiClient client)
{
	String data = String(air_temperature) + ",";
	data += String(air_humidity) + ",";
	data += String(soil_humidity_1) + ",";
	data += String(soil_humidity_2) + "\n";
	client.write(data.c_str());
	blink(50);
}
String getInstream(WiFiClient client)
{
	String inStream = "";
	while (client.available())
		inStream += (char)client.read();
	inStream.replace("\n", "");
	inStream.replace("\r", "");
	return inStream;
}
void doOprations(String comm, WiFiClient client)
{
	if (comm.equals("getData"))
		sendData(client);
	else if (comm.equals("cancelIrrigation"))
		cancelIrrigation = true;
		client.println("the Irrigation is canceled");
}
void readData()
{
	air_temperature = dht.readTemperature();
	air_humidity = dht.readHumidity();
	soil_humidity_1 = analogRead(S1P);
	soil_humidity_2 = analogRead(S2P);
	delay(10);
}
void sendAlarm(WiFiClient client)
{
	if (timeinfo.tm_hour == irrigation_1.getPastH(5) && timeinfo.tm_min == irrigation_1.getPastM(5))
	{
		client.println("Irrigation Time");
		blink(80);
		while (timeinfo.tm_hour == irrigation_1.getPastH(5) && timeinfo.tm_min == irrigation_1.getPastM(5) && client.connected())
		{
			doOprations(getInstream(client), client);
			readData();
			getTime();
		}
	}

	if (timeinfo.tm_hour == irrigation_2.getPastH(5) && timeinfo.tm_min == irrigation_2.getPastM(5))
	{
		client.println("Irrigation Time");
		blink(80);
		while (timeinfo.tm_hour == irrigation_2.getPastH(5) && timeinfo.tm_min == irrigation_2.getPastM(5) && client.connected())
		{
			doOprations(getInstream(client), client);
			readData();
			getTime();
		}
	}

	if (timeinfo.tm_hour == irrigation_3.getPastH(5) && timeinfo.tm_min == irrigation_3.getPastM(5))
	{
		client.println("Irrigation Time");
		blink(80);
		while (timeinfo.tm_hour == irrigation_3.getPastH(5) && timeinfo.tm_min == irrigation_3.getPastM(5) && client.connected())
		{
			doOprations(getInstream(client), client);
			readData();
			getTime();
		}
	}
}
void doIrrigation(WiFiClient client)
{
	if (timeinfo.tm_hour == irrigation_1.h && timeinfo.tm_min == irrigation_1.m)
	{
		if (cancelIrrigation)
		{
			while (timeinfo.tm_hour == irrigation_1.h && timeinfo.tm_min == irrigation_1.m)
				delay(1000);
			cancelIrrigation = false;
		}
		else
			while (1)
			{
				uint8_t v1 = 0, v2 = 0;
				if (soil_humidity_1 > Max_soil1t)
					v1 = 1;
				if (soil_humidity_2 > Max_soil2t)
					v2 = 1;
				if (soil_humidity_1 < Min_soil1t)
					v1=0;
				if (soil_humidity_2 < Min_soil2t)
					v2=0;
				if (v1==0 && v2 == 0)
				break;
				readData();
				setVol(v1, v2);
				
			}
		setVol(0, 0);
	}

	if (timeinfo.tm_hour == irrigation_2.h && timeinfo.tm_min == irrigation_2.m)
	{
		if (cancelIrrigation)
		{
			while (timeinfo.tm_hour == irrigation_2.h && timeinfo.tm_min == irrigation_2.m)
				delay(1000);
			cancelIrrigation = false;
		}
		else
			while (soil_humidity_1 > soil1t || soil_humidity_2 > soil2t)
			{
				uint8_t v1 = 0, v2 = 0;
				if (soil_humidity_1 > soil1t)
					v1 = 1;
				if (soil_humidity_2 > soil2t)
					v2 = 1;
				readData();
				setVol(v1, v2);
				
			}
		setVol(0, 0);
	}

	if (timeinfo.tm_hour == irrigation_3.h && timeinfo.tm_min == irrigation_3.m)
	{
		if (cancelIrrigation)
		{
			while (timeinfo.tm_hour == irrigation_3.h && timeinfo.tm_min == irrigation_3.m)
				delay(1000);
			cancelIrrigation = false;
		}
		else
			while (soil_humidity_1 > soil1t || soil_humidity_2 > soil2t)
			{
				uint8_t v1 = 0, v2 = 0;
				if (soil_humidity_1 > soil1t)
					v1 = 1;
				if (soil_humidity_2 > soil2t)
					v2 = 1;
				readData();
				setVol(v1, v2);
				
			}
		setVol(0, 0);
	}
}
void setup()
{
	setupTime();
	pinMode(VOL1, OUTPUT);
	pinMode(VOL2, OUTPUT);
	pinMode(LED_BUILTIN, OUTPUT);
	WiFi.config(local_IP, gateway, subnet);
	WiFi.begin(SSID, PSWD);
	while (WiFi.status() != WL_CONNECTED)
		blink(120);
	delay(5000);
	server.begin();
	dht.begin();
}
void loop()
{
	WiFiClient client = server.available();
	if (client)
		while (client.connected())
		{
			doOprations(getInstream(client), client);
			readData();
			getTime();
			sendAlarm(client);
			doIrrigation(client);
		}
	readData();
	getTime();
	doIrrigation(client);
}
