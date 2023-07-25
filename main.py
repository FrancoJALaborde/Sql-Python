from fastapi import FastAPI
from funtions import *
from fastapi.responses import HTMLResponse
import uvicorn

app = FastAPI()


@app.get("/api/plotCvsAR", response_class=HTMLResponse)
def plot_graph1a():
    return plot_graph1()


@app.get("/api/plotTop5ProdvsAR", response_class=HTMLResponse)
def plot_graph2a():
    return plot_graph2()


@app.get("/api/plotTopEmpvsProd", response_class=HTMLResponse)
def plot_graph3a():
    return plot_graph3()


@app.get("/api/plotExpvsExpT", response_class=HTMLResponse)
def plot_graph4a():
    return plot_graph4()


@app.get("/api/plotSalesvsYear", response_class=HTMLResponse)
def plot_graph5a():
    return plot_graph5()


@app.get("/api/plotSalesvsBetterYear", response_class=HTMLResponse)
def plot_graph6a():
    return plot_graph6()


@app.get("/api/plotMostProdvsMonBetterYear", response_class=HTMLResponse)
def plot_graph7a():
    return plot_graph7()


@app.get("/api/plotLeastProdvsMonBetterYear", response_class=HTMLResponse)
def plot_graph8a():
    return plot_graph8()


@app.get("/api/plotSalesvsWorseYear", response_class=HTMLResponse)
def plot_graph9a():
    return plot_graph9()


@app.get("/api/plotMostProdvsMonWorseYear", response_class=HTMLResponse)
def plot_graph10a():
    return plot_graph10()


@app.get("/api/plotLeastProdvsMonWorseYear", response_class=HTMLResponse)
def plot_graph11a():
    return plot_graph11()


if __name__ == "__main__":
    uvicorn.run(app, host="localhost", port=8000)
