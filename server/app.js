const express = require('express');
const cors = require('cors');
const mrzScanner = require('mrz-scan');
const multer = require('multer');
const path = require('path');
const { Pool } = require('pg');

const app = express();
const PORT = 3001;

const pool = new Pool({
  user: 'postgres',
  password: 'Sysadmin1',
  host: 'localhost',
  port: 5432,
  database: 'porteria',
});

app.use(cors());
app.use(express.json());

const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }
});

function limpiarRut(rut) {
  if (!rut) return '';
  return rut.replace(/[^0-9Kk]/g, '').toUpperCase();
}

function formatMRZResult(result) {
  if (!result || !result.fields) return null;
  
  const fields = result.fields;
  const rut = fields.optional2 
    ? fields.optional2.replace(' ', '-') 
    : '';
  const sexo = fields.sex === 'male' ? 'M' : 'F';
  
  let primerNombre = fields.firstName || '';
  if (primerNombre.includes(' ')) {
    primerNombre = primerNombre.split(' ')[0];
  }
  
  return {
    format: result.format,
    valid: result.valid,
    data: {
      nombres: primerNombre,
      apellidos: fields.lastName || '',
      rut: rut,
      numero_carnet: fields.documentNumber || '',
      sexo: sexo,
      nacionalidad: fields.nationality || '',
      destino: '',
      patente: null,
      comentarios: null,
      fecha_nacimiento: fields.birthDate || '',
      fecha_expiracion: fields.expirationDate || '',
      pais_emisor: fields.issuingState || '',
      tipo_documento: fields.documentCode || ''
    }
  };
}

app.post('/api/scan', upload.single('image'), async (req, res) => {
  console.log('\n[API] === ESCANEO MRZ ===');
  console.log('[API] Imagen recibida:', req.file ? req.file.originalname : 'NO');
  
  try {
    if (!req.file) {
      console.log('[API] ERROR: No se encontró imagen');
      return res.status(400).json({ 
        success: false, 
        error: 'No se encontró imagen' 
      });
    }

    const imageBuffer = req.file.buffer;
    console.log('[API] Procesando imagen...');
    const result = await mrzScanner(imageBuffer, { original: true });
    
    if (!result) {
      console.log('[API] ERROR: No se detectó MRZ');
      return res.json({ 
        success: false, 
        error: 'No se detectó MRZ en la imagen',
        data: null
      });
    }

    console.log('[API] MRZ detectado:', result.format);
    console.log('[API] Válido:', result.valid);
    console.log('[API] Campos:', JSON.stringify(result.fields, null, 2));

    const formattedResult = formatMRZResult(result);
    
    console.log('[API] Resultado formateado:', JSON.stringify(formattedResult.data, null, 2));
    console.log('[API] === FIN ESCANEO ===\n');
    
    res.json({
      success: true,
      data: formattedResult.data,
      meta: {
        format: formattedResult.format,
        valid: formattedResult.valid
      }
    });

  } catch (error) {
    console.error('[API] ERROR processing image:', error.message);
    res.status(500).json({ 
      success: false, 
      error: 'Error al procesar la imagen',
      details: error.message
    });
  }
});

app.post('/api/check-blacklist', async (req, res) => {
  const { rut, usuario_id } = req.body;
  
  console.log('\n[API] === VERIFICAR BLACKLIST ===');
  console.log('[API] RUT:', rut);
  console.log('[API] Usuario ID:', usuario_id);
  
  if (!rut || !usuario_id) {
    return res.json({ is_blacklist: false });
  }
  
  try {
    const rutLimpio = limpiarRut(rut);
    console.log('[API] RUT limpio:', rutLimpio);
    
    const userOrgsResult = await pool.query(
      'SELECT organizacion_id FROM usuario_organizaciones WHERE usuario_id = $1',
      [usuario_id]
    );
    
    const orgIds = userOrgsResult.rows.map(r => r.organizacion_id);
    
    const userResult = await pool.query(
      'SELECT organizacion_id FROM usuarios WHERE id = $1',
      [usuario_id]
    );
    
    if (userResult.rows.length > 0) {
      const userOrgId = userResult.rows[0].organizacion_id;
      if (userOrgId && !orgIds.includes(userOrgId)) {
        orgIds.push(userOrgId);
      }
    }
    
    console.log('[API] Org IDs:', orgIds);
    
    if (orgIds.length === 0) {
      console.log('[API] Sin organizaciones, no hay blacklist');
      return res.json({ is_blacklist: false });
    }
    
    const blacklistResult = await pool.query(
      'SELECT rut, motivo, organizacion_id FROM lista_negra WHERE organizacion_id = ANY($1)',
      [orgIds]
    );
    
    console.log('[API] Registros blacklist encontrados:', blacklistResult.rows.length);
    
    let encontrado = null;
    for (const row of blacklistResult.rows) {
      if (limpiarRut(row.rut) === rutLimpio) {
        encontrado = {
          motivo: row.motivo,
          organizacion_id: row.organizacion_id,
        };
        console.log('[API] BLACKLIST MATCH! Motivo:', encontrado.motivo);
        break;
      }
    }
    
    if (encontrado) {
      console.log('[API] === FIN BLACKLIST: BLOQUEADO ===\n');
      return res.json({
        is_blacklist: true,
        motivo: encontrado.motivo,
        message: `BLOQUEADO: ${encontrado.motivo}`,
      });
    }
    
    console.log('[API] === FIN BLACKLIST: NO BLOQUEADO ===\n');
    res.json({ is_blacklist: false });
    
  } catch (error) {
    console.error('[API] ERROR check-blacklist:', error.message);
    res.json({ is_blacklist: false, error: error.message });
  }
});

app.post('/api/login', (req, res) => {
  const { email, password } = req.body;
  
  if (!email || !password) {
    return res.status(400).json({ 
      success: false, 
      error: 'Email y contraseña requeridos' 
    });
  }
  
  setTimeout(() => {
    if (email === 'demo@test.com' && password === '123456') {
      res.json({
        success: true,
        user: {
          id: 1,
          name: 'Usuario Demo',
          email: email,
          token: 'demo_token_123456'
        }
      });
    } else {
      res.json({
        success: false,
        error: 'Credenciales inválidas'
      });
    }
  }, 1000);
});

app.get('/api/scans/:userId', (req, res) => {
  const mockScans = [
    {
      id: 1,
      nombres: 'FELIPE ANTO',
      apellidos: 'VALENZUELA CUEVAS',
      rut: '20690939-0',
      numero_carnet: '535264638',
      sexo: 'M',
      nacionalidad: 'CHL',
      fecha_scan: new Date().toISOString(),
      thumbnail: null
    },
    {
      id: 2,
      nombres: 'MARIA JOSEFINA',
      apellidos: 'GOMEZ SILVA',
      rut: '15234567-8',
      numero_carnet: '123456789',
      sexo: 'F',
      nacionalidad: 'CHL',
      fecha_scan: new Date(Date.now() - 86400000).toISOString(),
      thumbnail: null
    },
    {
      id: 3,
      nombres: 'PEDRO PABLO',
      apellidos: 'RODRIGUEZ MARTINEZ',
      rut: '9876543-2',
      numero_carnet: '987654321',
      sexo: 'M',
      nacionalidad: 'CHL',
      fecha_scan: new Date(Date.now() - 172800000).toISOString(),
      thumbnail: null
    }
  ];
  
  res.json({
    success: true,
    scans: mockScans
  });
});

app.listen(PORT, '0.0.0.0',() => {
  console.log(`========================================`);
  console.log(`  🚀 MRZ API Server`);
  console.log(`  📍 http://localhost:${PORT}`);
  console.log(`========================================`);
  console.log(`  POST /api/scan           - Escanear carnet`);
  console.log(`  POST /api/check-blacklist - Verificar lista negra`);
  console.log(`  POST /api/login          - Login usuario`);
  console.log(`  GET  /api/scans/:id      - Ver escaneos`);
  console.log(`========================================`);
});