from flask import Flask, jsonify, render_template, request, redirect, flash
import pymssql 
import datetime
from pymssql import output 

app = Flask(__name__)
app.secret_key = 'qwerty'
conexion=pymssql.connect(
    server="25.1.54.2",       
    user="sa",
    password="382005ALH",
    database="Proyecto3BD",
    autocommit=True
)

@app.route('/')
def inicio():
    return render_template('index.html')

@app.route('/pagos', methods=['POST','GET'])
def login():

    if request.method == 'POST':
        
        identificacion = request.form.get('filtroIdentificación')
        idFinca= request.form.get('filtroPropiedad')
        cursor = conexion.cursor()
        idOp=None
        facturaAntigua=None

        if idFinca:
            idOp=idFinca
        else:
            idOp=identificacion

        if idOp:
            try:
                facturas=[]
                print(f"ID Operación recibido: {idOp}")
                sp='sp_ConsultarFacturasPortal' 
                params = (idOp,)
                cursor.callproc(sp, params)
                columnas = [column[0] for column in cursor.description]
                for row in cursor.fetchall():
                    facturas.append(dict(zip(columnas, row)))
                print(f"Facturas obtenidas: {facturas}")
                if facturas:
                    facturas_pendientes = [f for f in facturas if f['IdEstadoFactura'] == 1]
                    if facturas_pendientes:
                        facturas_pendientes.sort(key=lambda x: x['FechaVencimiento'])
                        facturaAntigua = facturas_pendientes[0]['IdFactura']
            except Exception as e:
                print(f"Error al ejecutar SP Login: {e}")

                flash("Identificación o numero de finca desconocido. Por favor intente de nuevo.", 'error')
            finally:
                if cursor:
                    cursor.close()
                return render_template("pagos.html", facturas=facturas, facturaAntigua=facturaAntigua, idOp=idOp)

@app.route('/pagarFactura', methods=['POST'])
def pagarFactura():
    cursor = conexion.cursor()
    try:
        finca=request.form.get('numeroFinca')
        sp='sp_PagarFacturaPortal' 
        print(f"Número de finca para pagar factura: {finca}")
        outParam = output(int)
        params = (finca, 2, outParam)
        cursor.callproc(sp, params)
        fila=cursor.fetchone()
        codigo_resultado = fila[0]
        print(f"Código de resultado del SP (pymssql): {codigo_resultado}")
        flash("Pago realizado con éxito.", 'success')

        if codigo_resultado == 0:
            flash("Pago realizado con éxito.", 'success')
            return redirect('/')
        elif codigo_resultado in (50005,50001):
            flash("Error al pagar. Intente nuevamente", 'info')
            return redirect('/')

    except Exception as e:
        print(f"Error al ejecutar SP pagarFactura: {e}")
        flash("Error al procesar el pago. Por favor intente de nuevo.", 'error')

    finally:
        if cursor:
            cursor.close()
        return redirect('/')

if __name__ == '__main__':
    app.run(host='25.1.48.153', port=5000, debug=True)