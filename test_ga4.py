import os
from google.analytics.data_v1beta import BetaAnalyticsDataClient
from google.analytics.data_v1beta.types import RunReportRequest, DateRange, Metric

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "/app/secrets/ga4-service-account.json"

PROPERTY_ID = "562461404"

client = BetaAnalyticsDataClient()

request = RunReportRequest(
    property=f"properties/{PROPERTY_ID}",
    date_ranges=[DateRange(start_date="7daysAgo", end_date="today")],
    metrics=[Metric(name="activeUsers"), Metric(name="screenPageViews")],
)

try:
    response = client.run_report(request)
    print("\n✅ Conexión exitosa a Google Analytics")
    print("="*40)
    if not response.rows:
        print("No hay datos disponibles para los últimos 7 días.")
    else:
        for row in response.rows:
            print(f"Usuarios activos: {row.metric_values[0].value}")
            print(f"Páginas vistas: {row.metric_values[1].value}")
    print("="*40)
except Exception as e:
    print(f"\n❌ Error al conectar: {e}")
