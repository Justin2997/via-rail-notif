from fastapi import FastAPI, HTTPException
import requests

app = FastAPI()

  
@app.get("/data/station")
def fetch_data():
    url = "https://tsimobile.viarail.ca/data/allData.json"
    try:
        response = requests.get(url, timeout=2.50)
        response.raise_for_status()  # Raise an error for bad responses (4xx and 5xx)
        data = response.json()  # Parse the JSON data
        return data
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Error fetching data: {e}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)