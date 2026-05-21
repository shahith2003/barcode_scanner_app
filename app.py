from flask import Flask, request, jsonify
from flask_cors import CORS
import pyodbc

app = Flask(__name__)
CORS(app)

# SQL Server connection
conn = pyodbc.connect(
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=SHAHITH\\SQLEXPRESS;'
    'DATABASE=MobileApplication;'
    'Trusted_Connection=yes;'
)

cursor = conn.cursor()

@app.route('/save-barcode', methods=['POST'])
def save_barcode():
    data = request.json
    barcode = data.get('barcode')

    cursor.execute(
        "INSERT INTO scanned_codes (barcode) VALUES (?)",
        barcode
    )

    conn.commit()

    return jsonify({
        "message": "Barcode saved successfully"
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)