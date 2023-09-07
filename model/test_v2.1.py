import numpy as np  
import pandas as pd
from datetime import date, timedelta
import os
import subprocess
from swarmlearning.pyt import SwarmCallback

print("Test started")
print("User: ", os.environ.get("USER"))
print("User: ", subprocess.check_output("who"))
print("Working directory: " , os.getcwd()) 
print(f"Contents: {os.listdir()}")

#Load tidy data
print("Loading tidy data")
df_xy = pd.read_csv("data/df_xy_synth_v1.csv")

# create train, validation and test datasets: IMPUTE nan: -1
df_train = df_xy.fillna(-1)
df_test = df_train.sample(frac=0.2)
df_train = df_train.drop(df_test.index)
df_val = df_train.sample(frac=0.2)
df_train = df_train.drop(df_val.index)

# Numerical feature columns for standardizer
cols_standardize = df_xy.iloc[:,3:].columns

# For preprocessing
print("Loading sklearn")
from sklearn.preprocessing import StandardScaler
from sklearn_pandas import DataFrameMapper 

print("Loading torch")
import torch # For building the networks 
import torchtuples as tt # Some useful functionsci  swop

print("Loading pycox")
# from pycox.models import LogisticHazard
# from pycox.models import PMF
from pycox.models import DeepHitSingle
#from pycox.models import CoxPH #CoxPH = DeepSurv
#from pycox.evaluation import EvalSurv

#cols_standardize = df_x.columns

cols_standardize = df_xy.iloc[:,3:].columns
standardize = [([col], StandardScaler()) for col in cols_standardize]
#leave = [(col, None) for col in cols_leave]

x_mapper = DataFrameMapper(standardize)
x_train = x_mapper.fit_transform(df_train).astype('float32')
x_val = x_mapper.transform(df_val).astype('float32')
x_test = x_mapper.transform(df_test).astype('float32')
#print(x_train)
print(f"Training data:   {x_train.shape[0]}")
print(f"Test data:       {x_test.shape[0]}")
print(f"Validation data: {x_val.shape[0]}")

# Target mapping : DeepHit requires label_transform (dicretise times)

num_durations = 10
timepoints = np.array([0, 30.5*3, 30.5*6, 30.5*9, 365, 2*365, 3*365, 4*365, 5*365, 10*3>

# Label transform (note: different for CoxPH):
labtrans = DeepHitSingle.label_transform(timepoints)

get_target = lambda df: (df['OSS_days'].values, df['OSS_status'].values)
y_train = labtrans.fit_transform(*get_target(df_train))
y_val = labtrans.transform(*get_target(df_val))

train = (x_train, y_train)
val = (x_val, y_val)
# We don't need to transform the test labels
survival_test, events_test = get_target(df_test)
# For curiosity, we will use this later:
survival_train, events_train = get_target(df_train)

# Define Model
in_features = x_train.shape[1]
num_nodes = [16, 16]
out_features = labtrans.out_features
batch_norm = True
dropout = 0.4

# Define ANN
print("Creating ANN")
net = tt.practical.MLPVanilla(in_features, num_nodes, out_features, batch_norm, dropout)

print("Creating model")
optimizer = tt.optim.Adam(0.005)
model = DeepHitSingle(net, optimizer, duration_index=labtrans.cuts)


# Create Swarm callback
print("Creating swarm callback")

# Assign swarm callback parameters:
swSyncInterval=2
default_max_epochs = 100
default_min_peers = 1
max_epochs = int(os.getenv('MAX_EPOCHS', str(default_max_epochs)))
min_peers = int(os.getenv('MIN_PEERS', str(default_min_peers)))
print("max_epochs =", max_epochs)
# This one is also for training (that means also used belwo by method model.fit()
batch_size = x_train.shape[0]

# Create Swarm callback with above parameters
swarmCallback = None
swarmCallback = SwarmCallback(syncFrequency=swSyncInterval,
    minPeers=min_peers,
    useAdaptiveSync=False,
    #adsValData=[],
    adsValBatchSize=batch_size,
    model=net.net)
    
# Create tt.Callback from Swarm callback
class SLCallback(tt.cb.Callback):
    '''Temple for how to write callbacks.
        '''
    def give_model(self, model):
        self.model = model
        self.epoch = 0

    def on_fit_start(self):
        print("pyCox callback: Fitting started")
        self.epoch = 0        
        swarmCallback.on_train_begin()

    def on_epoch_start(self):
        self.epoch += 1
        pass

    def on_batch_start(self):
        pass

    def before_step(self):
        """Called after loss.backward(), but before optim.step()."""
        pass

    def on_batch_end(self):
        swarmCallback.on_batch_end()

    def on_epoch_end(self):
        #print("pyCox callback: Epoch ended")
        swarmCallback.on_epoch_end(self.epoch)

    def on_fit_end(self):
        print("pyCox callback: Training completed")
        swarmCallback.on_train_end()
        
# Train model
print("py model file: Training model")
callbacks = [tt.cb.EarlyStopping(), SLCallback()]
log = model.fit(x_train, y_train, batch_size, epochs=100, callbacks=callbacks, val_data>


print("py model file: Finished training model")

#with open('run_log.txt', 'w') as f:
#    #f.write('Model Training log:')
#    f.writeline('Model Training log:')
#
filename = "result/saved_model" 
model.save_net(filename+'_net.pytorch.pkl')
model.save_model_weights(filename+'_weights.pkl')
print(f"py model file: Model saved under \"{filename}\"")

print("Done!")
